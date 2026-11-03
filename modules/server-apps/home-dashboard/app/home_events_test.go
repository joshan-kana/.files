package main

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHomeStateEventReconciliation(t *testing.T) {
	states := map[string]homeEntity{}
	first := homeStateEvent{Added: map[string]homeCompactState{
		"fan.bedroom":             {State: "off", Attributes: map[string]any{"percentage": float64(0), "preset_mode": "Normal", "obsolete": true}},
		"light.bedroom":           {State: "on", Attributes: map[string]any{"brightness": float64(180)}},
		"invalid.should.not.work": {State: "on"},
	}}
	changes, removed := applyHomeStateEvent(states, first)
	if len(changes) != 2 || len(removed) != 0 || len(states) != 2 {
		t.Fatalf("first event: changes=%d removed=%d states=%d", len(changes), len(removed), len(states))
	}
	state := "on"
	var second homeStateEvent
	second.Changed = map[string]homeStatePatch{"fan.bedroom": {}}
	patch := second.Changed["fan.bedroom"]
	patch.Added.State = &state
	patch.Added.Attributes = map[string]any{"percentage": float64(66)}
	patch.Removed.Attributes = []string{"obsolete"}
	second.Changed["fan.bedroom"] = patch
	changes, removed = applyHomeStateEvent(states, second)
	if len(changes) != 1 || len(removed) != 0 {
		t.Fatalf("change event: changes=%d removed=%d", len(changes), len(removed))
	}
	fan := states["fan.bedroom"]
	if fan.State != "on" || fan.Attributes["percentage"] != float64(66) || fan.Attributes["preset_mode"] != "Normal" {
		t.Fatalf("partial change did not preserve state: %#v", fan)
	}
	if _, exists := fan.Attributes["obsolete"]; exists {
		t.Fatal("removed attribute remained in reconstructed state")
	}
	changes, removed = applyHomeStateEvent(states, homeStateEvent{Removed: []string{"fan.bedroom"}})
	if len(changes) != 0 || len(removed) != 1 || removed[0] != "fan.bedroom" || len(states) != 1 {
		t.Fatalf("remove event: changes=%d removed=%v states=%d", len(changes), removed, len(states))
	}
}

func TestHomeStreamAccessAndLiveEvents(t *testing.T) {
	upgrader := websocket.Upgrader{}
	connected := make(chan string, 1)
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/websocket" {
			http.NotFound(w, r)
			return
		}
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Error(err)
			return
		}
		defer conn.Close()
		conn.WriteJSON(map[string]any{"type": "auth_required"})
		var auth struct {
			Type        string `json:"type"`
			AccessToken string `json:"access_token"`
		}
		if err := conn.ReadJSON(&auth); err != nil {
			t.Error(err)
			return
		}
		if auth.Type != "auth" || auth.AccessToken != "test-only-secret" {
			t.Errorf("incorrect upstream auth")
			return
		}
		connected <- auth.Type
		conn.WriteJSON(map[string]any{"type": "auth_ok"})
		var sub struct {
			ID   int    `json:"id"`
			Type string `json:"type"`
		}
		if err := conn.ReadJSON(&sub); err != nil {
			t.Error(err)
			return
		}
		if sub.ID != 1 || sub.Type != "subscribe_entities" {
			t.Errorf("unexpected subscription: %+v", sub)
			return
		}
		conn.WriteJSON(map[string]any{"id": 1, "type": "result", "success": true})
		conn.WriteJSON(map[string]any{"id": 1, "type": "event", "event": map[string]any{"a": map[string]any{"fan.bedroom": map[string]any{"s": "off", "a": map[string]any{"percentage": 0}}}}})
		conn.WriteJSON(map[string]any{"id": 1, "type": "event", "event": map[string]any{"c": map[string]any{"fan.bedroom": map[string]any{"+": map[string]any{"s": "on", "a": map[string]any{"percentage": 66}}}}}})
		// Keep the connection active until the browser closes its stream.
		conn.ReadMessage()
	}))
	defer upstream.Close()
	old := upstreams["homeassistant"]
	upstreams["homeassistant"] = upstream.URL
	t.Cleanup(func() { upstreams["homeassistant"] = old })

	s, err := newServer(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	s.data.Users["viewer"] = &User{Name: "viewer", Enabled: true, Pages: map[string]bool{"home": true}, Credentials: map[string]string{"homeassistant": s.encrypt("test-only-secret")}, Version: 1}
	s.data.Users["blocked"] = &User{Name: "blocked", Enabled: true, Pages: map[string]bool{}, Version: 1}
	server := httptest.NewServer(s.handler())
	defer server.Close()
	client := &http.Client{Timeout: 4 * time.Second}
	for _, tc := range []struct {
		name   string
		cookie string
		want   int
	}{
		{"signed out", "", http.StatusForbidden},
		{"not permitted", s.token(s.data.Users["blocked"]), http.StatusForbidden},
	} {
		req, _ := http.NewRequest("GET", server.URL+"/api/ha/events", nil)
		if tc.cookie != "" {
			req.AddCookie(&http.Cookie{Name: "session", Value: tc.cookie})
		}
		res, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != tc.want {
			t.Errorf("%s: got %d, want %d", tc.name, res.StatusCode, tc.want)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, "GET", server.URL+"/api/ha/events", nil)
	req.AddCookie(&http.Cookie{Name: "session", Value: s.token(s.data.Users["viewer"])})
	res, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK || !strings.Contains(res.Header.Get("Content-Type"), "text/event-stream") || res.Header.Get("X-Accel-Buffering") != "no" {
		t.Fatalf("stream headers: %d %+v", res.StatusCode, res.Header)
	}
	reader := bufio.NewScanner(res.Body)
	var events []string
	for reader.Scan() {
		line := reader.Text()
		if strings.HasPrefix(line, "data: ") {
			var data map[string]json.RawMessage
			if err := json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &data); err != nil {
				t.Fatal(err)
			}
			if strings.Contains(line, "test-only-secret") {
				t.Fatal("upstream token leaked in stream")
			}
			events = append(events, line)
			if len(events) >= 2 {
				break
			}
		}
	}
	if len(events) != 2 || !strings.Contains(events[0], `"state":"off"`) || !strings.Contains(events[1], `"state":"on"`) {
		t.Fatalf("expected snapshot and delta, got %v (scanner: %v)", events, reader.Err())
	}
	select {
	case <-connected:
	case <-time.After(time.Second):
		t.Fatal("upstream auth was not established")
	}
}

func TestHomeSocketURL(t *testing.T) {
	for _, tc := range []struct{ base, want string }{
		{"http://127.0.0.1:8123", "ws://127.0.0.1:8123/api/websocket"},
		{"https://example.test:8123/prefix?x=1", "wss://example.test:8123/api/websocket"},
	} {
		got, err := homeSocketURL(tc.base)
		if err != nil || got != tc.want {
			t.Fatalf("%s: got %s, err %v", tc.base, got, err)
		}
	}
	if _, err := homeSocketURL("file:///tmp/secret"); err == nil {
		t.Fatal("invalid socket scheme accepted")
	}
}

// TestHomeEventsLiveReadOnly validates the upstream subscription against an
// existing account without issuing device commands or changing account data.
func TestHomeEventsLiveReadOnly(t *testing.T) {
	dir := os.Getenv("HAVEN_LIVE_DATA_DIR")
	if dir == "" {
		t.Skip("requires an existing, explicitly selected application data directory")
	}
	s, err := newServer(dir)
	if err != nil {
		t.Fatal(err)
	}
	var credential string
	var selected *User
	for _, user := range s.data.Users {
		if user.Enabled && hasPage(user, "home") && user.Credentials["homeassistant"] != "" {
			credential, err = s.decrypt(user.Credentials["homeassistant"])
			selected = user
			if err != nil {
				t.Fatal("could not access configured Home Assistant credential")
			}
			break
		}
	}
	if credential == "" {
		t.Skip("no enabled account has a Home Assistant integration")
	}
	address, err := homeSocketURL(upstreams["homeassistant"])
	if err != nil {
		t.Fatal(err)
	}
	conn, _, err := (&websocket.Dialer{HandshakeTimeout: 5 * time.Second}).Dial(address, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	conn.SetReadDeadline(time.Now().Add(10 * time.Second))
	var message homeWSMessage
	if err := conn.ReadJSON(&message); err != nil || message.Type != "auth_required" {
		t.Fatal("upstream handshake unavailable")
	}
	if err := conn.WriteJSON(map[string]string{"type": "auth", "access_token": credential}); err != nil {
		t.Fatal(err)
	}
	if err := conn.ReadJSON(&message); err != nil || message.Type != "auth_ok" {
		t.Fatal("upstream authentication rejected")
	}
	connected := time.Now()
	if err := conn.WriteJSON(map[string]any{"id": 1, "type": "subscribe_entities"}); err != nil {
		t.Fatal(err)
	}
	foundSnapshot := false
	states := make(map[string]homeEntity)
	for !foundSnapshot {
		if err := conn.ReadJSON(&message); err != nil {
			t.Fatal(err)
		}
		if message.ID != 1 {
			continue
		}
		if message.Type == "result" && !message.Success {
			t.Fatal("state subscription rejected")
		}
		if message.Type == "event" {
			var event homeStateEvent
			if err := json.Unmarshal(message.Event, &event); err != nil {
				t.Fatal(err)
			}
			applyHomeStateEvent(states, event)
			foundSnapshot = true
		}
	}
	elapsed := time.Since(connected)
	counts := map[string]int{}
	for id := range states {
		counts[strings.SplitN(id, ".", 2)[0]]++
	}
	t.Logf("Home Assistant live snapshot: %d permitted entities, %d light, %d fan, %d cover, %d climate, %d sensor; subscription-to-snapshot %s", len(states), counts["light"], counts["fan"], counts["cover"], counts["climate"], counts["sensor"], elapsed.Round(time.Millisecond))
	if err := conn.WriteJSON(map[string]any{"id": 2, "type": "config/entity_registry/list_for_display"}); err != nil {
		t.Fatal(err)
	}
	if err := conn.ReadJSON(&message); err != nil {
		t.Fatal(err)
	}
	if message.ID != 2 || message.Type != "result" || !message.Success {
		t.Fatal("entity registry display metadata unavailable")
	}
	var registry struct {
		Entities []json.RawMessage `json:"entities"`
	}
	if err := json.Unmarshal(message.Result, &registry); err != nil {
		t.Fatal("invalid display registry response")
	}
	var steppedFans int
	for id, state := range states {
		if strings.HasPrefix(id, "fan.") && state.Attributes["percentage_step"] != nil {
			steppedFans++
		}
	}
	t.Logf("Display registry: %d visible entries; fan speed-step metadata on %d fan states", len(registry.Entities), steppedFans)

	live := httptest.NewServer(s.handler())
	defer live.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, "GET", live.URL+"/api/ha/events", nil)
	if err != nil {
		t.Fatal(err)
	}
	req.AddCookie(&http.Cookie{Name: "session", Value: s.token(selected)})
	start := time.Now()
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("live stream returned HTTP %d", response.StatusCode)
	}
	scanner := bufio.NewScanner(response.Body)
	scanner.Buffer(make([]byte, 16384), 16<<20)
	var streamEntities struct {
		Entities []homeEntity `json:"entities"`
	}
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "data: ") {
			if err := json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &streamEntities); err != nil {
				t.Fatal(err)
			}
			break
		}
	}
	if err := scanner.Err(); err != nil {
		t.Fatal(err)
	}
	if len(streamEntities.Entities) != len(states) {
		t.Fatalf("SSE snapshot has %d entities, upstream subscription had %d", len(streamEntities.Entities), len(states))
	}
	t.Logf("Authenticated Haven SSE: %d permitted entities; initial end-to-end snapshot %s", len(streamEntities.Entities), time.Since(start).Round(time.Millisecond))
}
