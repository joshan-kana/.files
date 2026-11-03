package main

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHomeHubSharesOnlySameAccountAndCredential(t *testing.T) {
	var opened atomic.Int32
	var closed atomic.Int32
	var mu sync.Mutex
	upstreamConnections := map[string]*websocket.Conn{}
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := (&websocket.Upgrader{}).Upgrade(w, r, nil)
		if err != nil {
			return
		}
		opened.Add(1)
		write := func(value any) {
			mu.Lock()
			defer mu.Unlock()
			conn.WriteJSON(value)
		}
		defer func() {
			closed.Add(1)
			conn.Close()
		}()
		write(map[string]string{"type": "auth_required"})
		var auth struct {
			Type        string `json:"type"`
			AccessToken string `json:"access_token"`
		}
		if conn.ReadJSON(&auth) != nil || auth.Type != "auth" {
			return
		}
		write(map[string]string{"type": "auth_ok"})
		for i := 0; i < 7; i++ {
			var command struct {
				ID   int    `json:"id"`
				Type string `json:"type"`
			}
			if conn.ReadJSON(&command) != nil {
				return
			}
			result := any(nil)
			switch command.Type {
			case "config/entity_registry/list_for_display":
				result = map[string]any{"entities": []any{}}
			case "config/area_registry/list", "config/device_registry/list":
				result = []any{}
			}
			write(map[string]any{"id": command.ID, "type": "result", "success": true, "result": result})
		}
		mu.Lock()
		upstreamConnections[auth.AccessToken] = conn
		mu.Unlock()
		write(map[string]any{"id": 1, "type": "event", "event": map[string]any{
			"a": map[string]any{"fan.bedroom": map[string]any{"s": "off", "a": map[string]any{"percentage": 0}}},
		}})
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}))
	defer upstream.Close()
	previous := upstreams["homeassistant"]
	upstreams["homeassistant"] = upstream.URL
	t.Cleanup(func() { upstreams["homeassistant"] = previous })

	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	bob := addUser(s, "bob", false, map[string]bool{"home": true})
	alice.Credentials["homeassistant"] = s.encrypt("token-alice")
	bob.Credentials["homeassistant"] = s.encrypt("token-bob")
	web := httptest.NewServer(s.handler())
	defer web.Close()

	type stream struct {
		res    *http.Response
		reader *bufio.Scanner
		cancel context.CancelFunc
	}
	connect := func(user *User) stream {
		t.Helper()
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, web.URL+"/api/ha/events", nil)
		req.AddCookie(&http.Cookie{Name: "session", Value: s.token(user)})
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			cancel()
			t.Fatal(err)
		}
		if res.StatusCode != http.StatusOK {
			res.Body.Close()
			cancel()
			t.Fatalf("stream returned %d", res.StatusCode)
		}
		sc := bufio.NewScanner(res.Body)
		readEvent(t, sc, "snapshot")
		return stream{res, sc, cancel}
	}
	dispose := func(st stream) {
		st.cancel()
		st.res.Body.Close()
	}
	one := connect(alice)
	defer dispose(one)
	two := connect(alice)
	defer dispose(two)
	if opened.Load() != 1 {
		t.Fatalf("two tabs opened %d Home Assistant sockets; expected one", opened.Load())
	}
	third := connect(bob)
	defer dispose(third)
	if opened.Load() != 2 {
		t.Fatalf("different accounts used %d sockets; expected two", opened.Load())
	}
	// Rotate Alice's credential without revoking her authentication cookie.
	s.mu.Lock()
	s.data.Users["alice"].Credentials["homeassistant"] = s.encrypt("token-rotated")
	s.mu.Unlock()
	mu.Lock()
	conn := upstreamConnections["token-alice"]
	if conn == nil {
		mu.Unlock()
		t.Fatal("missing original account socket")
	}
	err := conn.WriteJSON(map[string]any{"id": 1, "type": "event", "event": map[string]any{
		"c": map[string]any{"fan.bedroom": map[string]any{"+": map[string]any{"s": "on"}}},
	}})
	mu.Unlock()
	if err != nil {
		t.Fatal(err)
	}
	readEvent(t, one.reader, "status")
	readEvent(t, two.reader, "status")
	rotated := connect(alice)
	defer dispose(rotated)
	if opened.Load() != 3 {
		t.Fatalf("rotated credential reused original socket: %d", opened.Load())
	}
	dispose(one)
	dispose(two)
	dispose(rotated)
	// Bob's independent connection must survive all Alice stream closures.
	deadline := time.Now().Add(time.Second)
	for closed.Load() < 2 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if closed.Load() < 2 || closed.Load() >= 3 {
		t.Fatalf("upstream socket lifetime mismatch: opened=%d closed=%d", opened.Load(), closed.Load())
	}
	readable := make(chan bool, 1)
	go func() {
		mu.Lock()
		conn := upstreamConnections["token-bob"]
		ok := conn != nil && conn.WriteJSON(map[string]any{"id": 1, "type": "event", "event": map[string]any{"c": map[string]any{"fan.bedroom": map[string]any{"+": map[string]any{"s": "on"}}}}}) == nil
		mu.Unlock()
		readable <- ok
	}()
	if !<-readable {
		t.Fatal("other account's socket was unexpectedly closed")
	}
	readEvent(t, third.reader, "delta")
}

func readEvent(t *testing.T, scanner *bufio.Scanner, want string) {
	t.Helper()
	kind := ""
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			kind = strings.TrimPrefix(line, "event: ")
		}
		if strings.HasPrefix(line, "data: ") && kind == want {
			var decoded json.RawMessage
			if json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &decoded) != nil {
				t.Fatal("invalid SSE event JSON")
			}
			return
		}
	}
	t.Fatalf("stream ended before %s: %v", want, scanner.Err())
}

func TestHomeHubDropsSlowSubscribers(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	h := &streamHub{cancel: cancel, subs: map[chan homeMessage]struct{}{}, states: map[string]homeEntity{}}
	slow := make(chan homeMessage, 1)
	fast := make(chan homeMessage, 64)
	h.subs[slow] = struct{}{}
	h.subs[fast] = struct{}{}
	for i := 0; i < 4; i++ {
		h.publish("delta", map[string]any{"changes": []any{}, "removed": []any{}})
	}
	if _, exists := h.subs[slow]; exists {
		t.Fatal("unresponsive subscriber retained")
	}
	if _, exists := h.subs[fast]; !exists {
		t.Fatal("healthy subscriber dropped")
	}
	select {
	case <-ctx.Done():
		t.Fatal("one slow tab stopped the healthy stream")
	default:
	}
}
