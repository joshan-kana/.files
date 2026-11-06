package main

import (
	"bufio"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestHomeRegistryMetadataFilteringAndInheritance(t *testing.T) {
	registry := haRegistryData{
		Entities: haDisplayRegistry{Entities: []haDisplayEntry{
			{EntityID: "fan.bedroom", DeviceID: "fan-child"},
			{EntityID: "light.office", AreaID: "study", DeviceID: "light"},
			{EntityID: "light.private", AreaID: "private", DeviceID: "secret"},
			{EntityID: "sensor.hidden", AreaID: "private", Hidden: true},
			{EntityID: "sensor.unregistered"},
		}},
		Devices: []haDeviceEntry{
			{ID: "fan-child", ParentDeviceID: "fan-parent", Name: "Fan"},
			{ID: "fan-parent", AreaID: "bedroom", Name: "Air system"},
			{ID: "light", NameByUser: "Desk lamp", Model: "Bulb"},
			{ID: "secret", AreaID: "private", Name: "Secret device"},
		},
		Areas: []haAreaEntry{
			{AreaID: "bedroom", Name: "Bedroom", Icon: "mdi:bed-king"},
			{AreaID: "study", Name: "Study", Icon: "mdi:chair-rolling"},
			{AreaID: "private", Name: "Private", Icon: "mdi:lock"},
		},
	}
	states := map[string]homeEntity{
		"fan.bedroom":         {EntityID: "fan.bedroom"},
		"light.office":        {EntityID: "light.office"},
		"sensor.hidden":       {EntityID: "sensor.hidden"},
		"sensor.unregistered": {EntityID: "sensor.unregistered"},
	}
	metadata := buildHomeRegistryMetadata(states, registry)
	if len(metadata.Devices) != 2 || metadata.Devices["fan.bedroom"].Room != "Bedroom" ||
		metadata.Devices["light.office"].Name != "Desk lamp" ||
		metadata.Areas["light.office"] != "Study" ||
		metadata.RoomIcons["Bedroom"] != "mdi:bed-king" {
		t.Fatalf("incorrect registry metadata: %+v", metadata)
	}
	if _, exists := metadata.Devices["light.private"]; exists {
		t.Fatal("unreadable device was disclosed")
	}
	if _, exists := metadata.Areas["sensor.hidden"]; exists {
		t.Fatal("hidden registry entity was disclosed")
	}
	if _, exists := metadata.RoomIcons["Private"]; exists {
		t.Fatal("unreadable area was disclosed")
	}
	if _, exists := metadata.Devices["sensor.unregistered"]; exists {
		t.Fatal("unregistered synthetic entity was added as a device")
	}
}

func TestHomeRegistryStreamUpdates(t *testing.T) {
	var sockets atomic.Int32
	protocolError := make(chan string, 1)
	ha := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/websocket" {
			select {
			case protocolError <- "unexpected upstream HTTP call":
			default:
			}
			http.NotFound(w, r)
			return
		}
		sockets.Add(1)
		conn, err := (&websocket.Upgrader{}).Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()
		conn.WriteJSON(map[string]any{"type": "auth_required"})
		var auth map[string]any
		if err := conn.ReadJSON(&auth); err != nil {
			return
		}
		if auth["access_token"] != "member-token" {
			protocolError <- "wrong upstream token"
			return
		}
		conn.WriteJSON(map[string]any{"type": "auth_ok"})
		requests := make(map[string]int)
		for i := 0; i < 7; i++ {
			var req struct {
				ID   int    `json:"id"`
				Type string `json:"type"`
			}
			if err := conn.ReadJSON(&req); err != nil {
				protocolError <- "could not read initial command"
				return
			}
			requests[req.Type] = req.ID
			switch req.Type {
			case "subscribe_entities", "subscribe_events":
				conn.WriteJSON(map[string]any{"id": req.ID, "type": "result", "success": true})
			case "config/entity_registry/list_for_display":
				conn.WriteJSON(map[string]any{"id": req.ID, "type": "result", "success": true,
					"result": map[string]any{"entities": []any{
						map[string]any{"ei": "fan.bedroom", "di": "fan-device", "ai": "bedroom"},
						map[string]any{"ei": "light.private", "di": "private-device", "ai": "hidden"},
					}},
				})
			case "config/device_registry/list":
				conn.WriteJSON(map[string]any{"id": req.ID, "type": "result", "success": true, "result": []any{
					map[string]any{"id": "fan-device", "name": "Bedroom fan", "model": "Three speed"},
					map[string]any{"id": "private-device", "name": "Private light"},
				}})
			case "config/area_registry/list":
				conn.WriteJSON(map[string]any{"id": req.ID, "type": "result", "success": true, "result": []any{
					map[string]any{"area_id": "bedroom", "name": "Bedroom", "icon": "mdi:bed-king"},
					map[string]any{"area_id": "hidden", "name": "Private", "icon": "mdi:lock"},
				}})
			default:
				protocolError <- "unexpected websocket command: " + req.Type
				return
			}
		}
		conn.WriteJSON(map[string]any{"id": requests["subscribe_entities"], "type": "event", "event": map[string]any{
			"a": map[string]any{"fan.bedroom": map[string]any{"s": "on", "a": map[string]any{"percentage": 66}}},
		}})
		// HA registry notification, then a fresh metadata snapshot.
		conn.WriteJSON(map[string]any{"id": 5, "type": "event", "event": map[string]any{"event_type": "entity_registry_updated"}})
		for i := 0; i < 3; i++ {
			var req struct {
				ID   int    `json:"id"`
				Type string `json:"type"`
			}
			if err := conn.ReadJSON(&req); err != nil {
				protocolError <- "registry notification did not trigger a new read"
				return
			}
			var result any
			switch req.Type {
			case "config/entity_registry/list_for_display":
				result = map[string]any{"entities": []any{map[string]any{"ei": "fan.bedroom", "di": "fan-device", "ai": "study"}}}
			case "config/device_registry/list":
				result = []any{map[string]any{"id": "fan-device", "name": "Bedroom fan", "model": "Three speed"}}
			case "config/area_registry/list":
				result = []any{map[string]any{"area_id": "study", "name": "Study", "icon": "mdi:chair-rolling"}}
			default:
				protocolError <- "unknown registry refresh: " + req.Type
				return
			}
			conn.WriteJSON(map[string]any{"id": req.ID, "type": "result", "success": true, "result": result})
		}
		conn.ReadMessage()
	}))
	defer ha.Close()
	previous := upstreams["homeassistant"]
	upstreams["homeassistant"] = ha.URL
	t.Cleanup(func() { upstreams["homeassistant"] = previous })
	s := testServer(t)
	member := addUser(s, "member", false, map[string]bool{"home": true})
	member.Credentials["homeassistant"] = s.encrypt("member-token")
	outsider := addUser(s, "outsider", false, map[string]bool{"apps": true})
	web := httptest.NewServer(s.handler())
	defer web.Close()
	for _, cookie := range []string{"", s.token(outsider)} {
		req, _ := http.NewRequest(http.MethodGet, web.URL+"/api/ha/events", nil)
		if cookie != "" {
			req.AddCookie(&http.Cookie{Name: "session", Value: cookie})
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		res.Body.Close()
		if res.StatusCode != 403 {
			t.Fatalf("unauthorised subscription returned %d", res.StatusCode)
		}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, web.URL+"/api/ha/events", nil)
	req.AddCookie(&http.Cookie{Name: "session", Value: s.token(member)})
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer res.Body.Close()
	scanner := bufio.NewScanner(res.Body)
	var events []struct {
		Type string
		Body string
	}
	name := ""
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "event: ") {
			name = strings.TrimPrefix(line, "event: ")
		} else if strings.HasPrefix(line, "data: ") {
			body := strings.TrimPrefix(line, "data: ")
			if strings.Contains(body, "member-token") || strings.Contains(body, "Private") {
				t.Fatalf("unauthorised registry data or token leaked in %s", name)
			}
			var payload json.RawMessage
			if json.Unmarshal([]byte(body), &payload) != nil {
				t.Fatal("invalid SSE JSON")
			}
			events = append(events, struct{ Type, Body string }{name, body})
			if len(events) >= 3 {
				break
			}
		}
	}
	if len(events) != 3 {
		t.Fatalf("expected snapshot + metadata + metadata refresh, got %v (%v)", events, scanner.Err())
	}
	var old, fresh homeRegistryMetadata
	var snapshots int
	for _, event := range events {
		switch event.Type {
		case "snapshot":
			snapshots++
		case "metadata":
			if old.Areas == nil {
				json.Unmarshal([]byte(event.Body), &old)
			} else {
				json.Unmarshal([]byte(event.Body), &fresh)
			}
		default:
			t.Fatalf("unexpected event %s", event.Type)
		}
	}
	if snapshots != 1 || old.Areas["fan.bedroom"] != "Bedroom" || fresh.Areas["fan.bedroom"] != "Study" || sockets.Load() != 1 {
		t.Fatalf("incorrect event-driven registry handling: %v, websocket connections=%d", events, sockets.Load())
	}
	select {
	case err := <-protocolError:
		t.Fatal(err)
	default:
	}
}
