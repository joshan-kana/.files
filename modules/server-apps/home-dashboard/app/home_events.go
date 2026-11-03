package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"time"

	"github.com/gorilla/websocket"
)

type homeEntity struct {
	EntityID   string         `json:"entity_id"`
	State      string         `json:"state"`
	Attributes map[string]any `json:"attributes"`
}

type homeCompactState struct {
	State      string         `json:"s"`
	Attributes map[string]any `json:"a"`
}

type homeStatePatch struct {
	Added struct {
		State      *string        `json:"s"`
		Attributes map[string]any `json:"a"`
	} `json:"+"`
	Removed struct {
		Attributes []string `json:"a"`
	} `json:"-"`
}

type homeStateEvent struct {
	Added   map[string]homeCompactState `json:"a"`
	Changed map[string]homeStatePatch   `json:"c"`
	Removed []string                    `json:"r"`
}

type homeWSMessage struct {
	ID      int             `json:"id"`
	Type    string          `json:"type"`
	Success bool            `json:"success"`
	Event   json.RawMessage `json:"event"`
	Result  json.RawMessage `json:"result"`
}

func applyHomeStateEvent(states map[string]homeEntity, event homeStateEvent) ([]homeEntity, []string) {
	updated := map[string]homeEntity{}
	removed := make([]string, 0, len(event.Removed))
	for id, item := range event.Added {
		if !entityPattern.MatchString(id) {
			continue
		}
		attrs := item.Attributes
		if attrs == nil {
			attrs = map[string]any{}
		}
		entity := homeEntity{EntityID: id, State: item.State, Attributes: attrs}
		states[id] = entity
		updated[id] = entity
	}
	for id, patch := range event.Changed {
		if !entityPattern.MatchString(id) {
			continue
		}
		entity, ok := states[id]
		if !ok {
			continue
		}
		if patch.Added.State != nil {
			entity.State = *patch.Added.State
		}
		attrs := make(map[string]any, len(entity.Attributes)+len(patch.Added.Attributes))
		for key, value := range entity.Attributes {
			attrs[key] = value
		}
		for key, value := range patch.Added.Attributes {
			attrs[key] = value
		}
		for _, key := range patch.Removed.Attributes {
			delete(attrs, key)
		}
		entity.Attributes = attrs
		states[id] = entity
		updated[id] = entity
	}
	for _, id := range event.Removed {
		if _, ok := states[id]; ok {
			delete(states, id)
			delete(updated, id)
			removed = append(removed, id)
		}
	}
	changes := make([]homeEntity, 0, len(updated))
	for _, entity := range updated {
		changes = append(changes, entity)
	}
	sort.Slice(changes, func(i, j int) bool { return changes[i].EntityID < changes[j].EntityID })
	sort.Strings(removed)
	return changes, removed
}

func homeStateSnapshot(states map[string]homeEntity) []homeEntity {
	entities := make([]homeEntity, 0, len(states))
	for _, entity := range states {
		entities = append(entities, entity)
	}
	sort.Slice(entities, func(i, j int) bool { return entities[i].EntityID < entities[j].EntityID })
	return entities
}

func homeSocketURL(address string) (string, error) {
	endpoint, err := url.Parse(address)
	if err != nil {
		return "", err
	}
	switch endpoint.Scheme {
	case "http":
		endpoint.Scheme = "ws"
	case "https":
		endpoint.Scheme = "wss"
	default:
		return "", errors.New("invalid Home Assistant protocol")
	}
	endpoint.Path = "/api/websocket"
	endpoint.RawQuery = ""
	endpoint.Fragment = ""
	return endpoint.String(), nil
}

type pendingHomeRegistry struct {
	ids    map[int]string
	data   haRegistryData
	failed bool
}

func requestHomeRegistry(conn *websocket.Conn, nextID *int) (pendingHomeRegistry, error) {
	pending := pendingHomeRegistry{ids: make(map[int]string, 3)}
	for _, command := range []struct{ kind, name string }{
		{"entities", "config/entity_registry/list_for_display"},
		{"devices", "config/device_registry/list"},
		{"areas", "config/area_registry/list"},
	} {
		id := *nextID
		*nextID = id + 1
		if err := conn.WriteJSON(map[string]any{"id": id, "type": command.name}); err != nil {
			return pendingHomeRegistry{}, err
		}
		pending.ids[id] = command.kind
	}
	return pending, nil
}

func (p *pendingHomeRegistry) receive(msg homeWSMessage) (matched, complete bool) {
	kind, exists := p.ids[msg.ID]
	if !exists || msg.Type != "result" {
		return false, false
	}
	delete(p.ids, msg.ID)
	if !msg.Success || decodeHomeRegistry(kind, msg.Result, &p.data) != nil {
		p.failed = true
	}
	return true, len(p.ids) == 0
}

func sendHomeEvent(w http.ResponseWriter, flush http.Flusher, event string, data any) error {
	body, err := json.Marshal(data)
	if err != nil {
		return err
	}
	if _, err := fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event, body); err != nil {
		return err
	}
	flush.Flush()
	return nil
}

func (s *Server) serveHomeEvents(w http.ResponseWriter, r *http.Request) {
	user := s.session(r)
	if !hasPage(user, "home") {
		failure(w, http.StatusForbidden, "Access denied")
		return
	}
	secret, err := s.decrypt(user.Credentials["homeassistant"])
	if err != nil || secret == "" {
		failure(w, http.StatusConflict, "Home Assistant not connected")
		return
	}
	address, err := homeSocketURL(upstreams["homeassistant"])
	if err != nil {
		failure(w, http.StatusBadGateway, "Home Assistant unavailable")
		return
	}
	flush, ok := w.(http.Flusher)
	if !ok {
		failure(w, http.StatusInternalServerError, "Streaming unavailable")
		return
	}

	ctx, cancel := context.WithCancel(r.Context())
	defer cancel()
	conn, _, err := (&websocket.Dialer{HandshakeTimeout: 5 * time.Second}).DialContext(ctx, address, nil)
	if err != nil {
		failure(w, http.StatusBadGateway, "Home Assistant unavailable")
		return
	}
	defer conn.Close()
	conn.SetReadLimit(16 << 20)
	conn.SetReadDeadline(time.Now().Add(8 * time.Second))
	var handshake homeWSMessage
	if err := conn.ReadJSON(&handshake); err != nil || handshake.Type != "auth_required" {
		failure(w, http.StatusBadGateway, "Home Assistant authentication unavailable")
		return
	}
	if err := conn.WriteJSON(map[string]string{"type": "auth", "access_token": secret}); err != nil {
		failure(w, http.StatusBadGateway, "Home Assistant authentication unavailable")
		return
	}
	if err := conn.ReadJSON(&handshake); err != nil || handshake.Type != "auth_ok" {
		failure(w, http.StatusBadGateway, "Home Assistant authentication failed")
		return
	}
	if err := conn.WriteJSON(map[string]any{"id": 1, "type": "subscribe_entities"}); err != nil {
		failure(w, http.StatusBadGateway, "Home Assistant subscription unavailable")
		return
	}
	nextID := 2
	pendingRegistry, err := requestHomeRegistry(conn, &nextID)
	if err != nil {
		failure(w, http.StatusBadGateway, "Home Assistant metadata unavailable")
		return
	}
	// Registry notifications invalidate metadata. They are intentionally
	// separate from state events; a user lacking permission to subscribe can
	// still receive the initial registry snapshot.
	for id, event := range []string{
		"entity_registry_updated",
		"device_registry_updated",
		"area_registry_updated",
	} {
		if err := conn.WriteJSON(map[string]any{
			"id": id + 5, "type": "subscribe_events", "event_type": event,
		}); err != nil {
			failure(w, http.StatusBadGateway, "Home Assistant registry notifications unavailable")
			return
		}
	}

	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache, no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Connection", "keep-alive")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "retry: 5000\n\n")
	flush.Flush()

	conn.SetReadDeadline(time.Now().Add(70 * time.Second))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(70 * time.Second))
	})
	messages := make(chan homeWSMessage, 64)
	readErrors := make(chan error, 1)
	go func() {
		for {
			var msg homeWSMessage
			if err := conn.ReadJSON(&msg); err != nil {
				readErrors <- err
				return
			}
			select {
			case messages <- msg:
			default:
				readErrors <- errors.New("Home Assistant event backlog exceeded")
				return
			}
		}
	}()
	heartbeat := time.NewTicker(20 * time.Second)
	defer heartbeat.Stop()
	states := make(map[string]homeEntity)
	initialised := false
	registryReady := false
	var registry haRegistryData
	// Coalesce bursts of registry edits into one request batch. This timer
	// responds to a change notification; it is not a periodic state fetch.
	var refreshTimer *time.Timer
	var refreshCh <-chan time.Time
	refreshPending := false
	defer func() {
		if refreshTimer != nil {
			refreshTimer.Stop()
		}
	}()
	publishRegistry := func() bool {
		return sendHomeEvent(w, flush, "metadata", buildHomeRegistryMetadata(states, registry)) == nil
	}
	for {
		select {
		case <-ctx.Done():
			return
		case <-heartbeat.C:
			if !hasPage(s.session(r), "home") {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "unauthorized"})
				return
			}
			if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(2*time.Second)); err != nil {
				return
			}
			if _, err := fmt.Fprint(w, ": keep-alive\n\n"); err != nil {
				return
			}
			flush.Flush()
		case <-readErrors:
			sendHomeEvent(w, flush, "status", map[string]string{"state": "offline"})
			return
		case <-refreshCh:
			refreshCh = nil
			if len(pendingRegistry.ids) != 0 {
				refreshPending = true
			} else {
				pendingRegistry, err = requestHomeRegistry(conn, &nextID)
				if err != nil {
					return
				}
			}
		case msg := <-messages:
			if !hasPage(s.session(r), "home") {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "unauthorized"})
				return
			}
			if matched, complete := pendingRegistry.receive(msg); matched {
				if complete {
					if !pendingRegistry.failed {
						registry = pendingRegistry.data
						registryReady = true
						if initialised && !publishRegistry() {
							return
						}
					} else if !registryReady {
						if sendHomeEvent(w, flush, "metadata-error", map[string]string{"state": "unavailable"}) != nil {
							return
						}
					}
					if refreshPending {
						refreshPending = false
						pendingRegistry, err = requestHomeRegistry(conn, &nextID)
						if err != nil {
							return
						}
					}
				}
				continue
			}
			if msg.ID >= 5 && msg.ID <= 7 && msg.Type == "event" {
				if refreshTimer == nil {
					refreshTimer = time.NewTimer(250 * time.Millisecond)
				} else {
					if !refreshTimer.Stop() {
						select {
						case <-refreshTimer.C:
						default:
						}
					}
					refreshTimer.Reset(250 * time.Millisecond)
				}
				refreshCh = refreshTimer.C
				continue
			}
			if msg.ID != 1 {
				continue
			}
			if msg.Type == "result" {
				if !msg.Success {
					sendHomeEvent(w, flush, "status", map[string]string{"state": "unavailable"})
					return
				}
				continue
			}
			if msg.Type != "event" {
				continue
			}
			var event homeStateEvent
			if err := json.Unmarshal(msg.Event, &event); err != nil {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "invalid"})
				return
			}
			changes, removed := applyHomeStateEvent(states, event)
			if !initialised {
				initialised = true
				if sendHomeEvent(w, flush, "snapshot", map[string]any{"entities": homeStateSnapshot(states)}) != nil {
					return
				}
				if registryReady && !publishRegistry() {
					return
				}
			} else if len(changes) != 0 || len(removed) != 0 {
				if sendHomeEvent(w, flush, "delta", map[string]any{"changes": changes, "removed": removed}) != nil {
					return
				}
				// New and removed entities can change the visible area/device
				// grouping even before a registry notification arrives.
				if registryReady && (len(event.Added) != 0 || len(event.Removed) != 0) && !publishRegistry() {
					return
				}
			}
		}
	}
}
