package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestArrSignalRFrameParser(t *testing.T) {
	tests := []struct {
		frame string
		want  bool
	}{
		{frame: `{"type":1,"target":"receiveMessage","arguments":[{"name":"movie"}]}`, want: true},
		{frame: `{"type":1,"target":"receiveMessage","arguments":[{"name":"download"}]}`, want: true},
		{frame: `{"type":6}`, want: false},
		{frame: `{"type":1,"target":"Unrelated"}`, want: false},
		{frame: `unparseable`, want: false},
	}
	for _, test := range tests {
		if got := arrSignalRNotification([]byte(test.frame)); got != test.want {
			t.Errorf("%s: got %v; want %v", test.frame, got, test.want)
		}
	}
}

func TestArrPushRefreshAndPermissionIsolation(t *testing.T) {
	var negotiated atomic.Int32
	var sockets atomic.Int32
	var queueReads atomic.Int32
	update := make(chan struct{}, 1)
	var socketMu sync.Mutex
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/signalr/messages/negotiate":
			if r.Method != http.MethodPost || r.Header.Get("X-Api-Key") != "personal-arr-key" {
				t.Error("negotiate did not use personal credential")
				http.Error(w, "unauthorized", 401)
				return
			}
			negotiated.Add(1)
			json.NewEncoder(w).Encode(map[string]any{"connectionToken": "test-connection", "negotiateVersion": 1})
		case r.URL.Path == "/signalr/messages":
			if r.URL.Query().Get("id") != "test-connection" || r.URL.Query().Get("access_token") != "personal-arr-key" {
				t.Error("invalid websocket negotiation token")
				http.Error(w, "bad token", 403)
				return
			}
			conn, err := (&websocket.Upgrader{}).Upgrade(w, r, nil)
			if err != nil {
				return
			}
			defer conn.Close()
			sockets.Add(1)
			_, hello, err := conn.ReadMessage()
			if err != nil || string(hello) != "{\"protocol\":\"json\",\"version\":1}\x1e" {
				t.Errorf("unexpected SignalR handshake: %q, %v", hello, err)
				return
			}
			conn.WriteMessage(websocket.TextMessage, []byte("{}\x1e"))
			// An upstream notification is produced only after the initial REST
			// queue snapshot has been fetched.
			select {
			case <-update:
				socketMu.Lock()
				conn.WriteMessage(websocket.TextMessage, []byte(`{"type":1,"target":"receiveMessage","arguments":[{"name":"download"}]}`+"\x1e"))
				socketMu.Unlock()
			case <-r.Context().Done():
				return
			}
			conn.ReadMessage()
		case r.URL.Path == "/api/v3/queue":
			if r.Header.Get("X-Api-Key") != "personal-arr-key" {
				t.Error("wrong API key for queue")
				http.Error(w, "unauthorized", 401)
				return
			}
			reads := queueReads.Add(1)
			status := "queued"
			if reads >= 2 {
				status = "downloading"
			}
			fmt.Fprintf(w, `{"totalRecords":1,"records":[{"id":1,"title":"Sample download","status":"%s","size":100,"sizeleft":50}]}`, status)
			if reads == 1 {
				update <- struct{}{}
			}
		default:
			t.Errorf("unexpected upstream request path %s", r.URL.Path)
			http.NotFound(w, r)
		}
	}))
	defer upstream.Close()
	old := upstreams["sonarr"]
	upstreams["sonarr"] = upstream.URL
	t.Cleanup(func() { upstreams["sonarr"] = old })

	s := testServer(t)
	viewer := addUser(s, "viewer", false, map[string]bool{"media": true})
	viewer.Credentials["sonarr"] = s.encrypt("personal-arr-key")
	blocked := addUser(s, "blocked", false, map[string]bool{"apps": true})
	web := httptest.NewServer(s.handler())
	defer web.Close()
	client := http.Client{Timeout: 5 * time.Second}
	for _, tc := range []struct {
		user *User
		path string
		want int
	}{
		{blocked, "/api/arr/events/sonarr", 403},
		{viewer, "/api/arr/events/unlisted", 404},
	} {
		req, _ := http.NewRequest(http.MethodGet, web.URL+tc.path, nil)
		req.AddCookie(&http.Cookie{Name: "session", Value: s.token(tc.user)})
		resp, err := client.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		resp.Body.Close()
		if resp.StatusCode != tc.want {
			t.Fatalf("expected HTTP %d, got %d", tc.want, resp.StatusCode)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, web.URL+"/api/arr/events/sonarr", nil)
	req.AddCookie(&http.Cookie{Name: "session", Value: s.token(viewer)})
	res, err := client.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK || !strings.HasPrefix(res.Header.Get("Content-Type"), "text/event-stream") {
		t.Fatalf("unexpected stream HTTP %d", res.StatusCode)
	}
	scanner := bufio.NewScanner(res.Body)
	name := ""
	statuses := []string{}
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			name = strings.TrimPrefix(line, "event: ")
		}
		if strings.HasPrefix(line, "data: ") && name == "queue" {
			if strings.Contains(line, "personal-arr-key") {
				t.Fatal("upstream token disclosed to browser")
			}
			var queue arrQueue
			if json.Unmarshal([]byte(strings.TrimPrefix(line, "data: ")), &queue) != nil || len(queue.Records) != 1 {
				t.Fatalf("invalid queue event: %s", line)
			}
			statuses = append(statuses, queue.Records[0].Status)
			if len(statuses) >= 2 {
				break
			}
		}
	}
	if len(statuses) != 2 || statuses[0] != "queued" || statuses[1] != "downloading" {
		t.Fatalf("initial snapshot and SignalR queue refresh failed: %v, scanner err=%v", statuses, scanner.Err())
	}
	if negotiated.Load() != 1 || sockets.Load() != 1 || queueReads.Load() != 2 {
		t.Fatalf("unexpected connection/request count: negotiated=%d sockets=%d queueReads=%d", negotiated.Load(), sockets.Load(), queueReads.Load())
	}
}

// TestLiveArrReadOnly connects only to already configured personal media
// credentials; it neither changes an upstream library nor discloses API keys.
func TestLiveArrReadOnly(t *testing.T) {
	dir := os.Getenv("HAVEN_LIVE_DATA_DIR")
	if dir == "" {
		t.Skip("live data directory not selected")
	}
	s, err := newServer(dir)
	if err != nil {
		t.Fatal(err)
	}
	var attempts int
	for _, u := range s.data.Users {
		if !u.Enabled || !hasPage(u, "media") {
			continue
		}
		for _, service := range []string{"sonarr", "radarr"} {
			if u.Credentials[service] == "" {
				continue
			}
			token, err := s.decrypt(u.Credentials[service])
			if err != nil {
				t.Fatal("saved media credentials could not be decrypted")
			}
			ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
			start := time.Now()
			conn, err := arrSignalRConnect(ctx, upstreams[service], token)
			if err != nil {
				cancel()
				t.Fatalf("%s SignalR subscription failed: %v", service, err)
			}
			queue, err := s.fetchArrQueue(u, service)
			conn.Close()
			cancel()
			if err != nil {
				t.Fatalf("%s queue read failed: %v", service, err)
			}
			attempts++
			t.Logf("%s: authenticated SignalR handshake and %d queue records in %s",
				service, len(queue.Records), time.Since(start).Round(time.Millisecond))
		}
	}
	if attempts == 0 {
		t.Skip("no configured personal Sonarr/Radarr credentials")
	}
}
