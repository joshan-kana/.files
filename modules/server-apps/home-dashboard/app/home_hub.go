package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"sync"
	"time"
)

type homeMessage struct {
	kind string
	data json.RawMessage
}

type streamHub struct {
	mu       sync.Mutex
	subs     map[chan homeMessage]struct{}
	cancel   context.CancelFunc
	closed   bool
	snapshot *homeMessage
	metadata *homeMessage
	states   map[string]homeEntity
}

func (h *streamHub) publish(kind string, value any) {
	raw, err := json.Marshal(value)
	if err != nil {
		return
	}
	msg := homeMessage{kind: kind, data: raw}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.closed {
		return
	}
	switch kind {
	case "snapshot":
		var payload struct {
			Entities []homeEntity `json:"entities"`
		}
		if json.Unmarshal(raw, &payload) == nil {
			h.states = make(map[string]homeEntity, len(payload.Entities))
			for _, entity := range payload.Entities {
				h.states[entity.EntityID] = entity
			}
			h.snapshot = &msg
		}
	case "delta":
		var payload struct {
			Changes []homeEntity `json:"changes"`
			Removed []string     `json:"removed"`
		}
		if json.Unmarshal(raw, &payload) == nil && h.snapshot != nil {
			for _, entity := range payload.Changes {
				h.states[entity.EntityID] = entity
			}
			for _, id := range payload.Removed {
				delete(h.states, id)
			}
			body, _ := json.Marshal(map[string]any{"entities": homeStateSnapshot(h.states)})
			h.snapshot = &homeMessage{kind: "snapshot", data: body}
		}
	case "metadata":
		h.metadata = &msg
	case "queue":
		h.snapshot = &msg
	}
	for subscriber := range h.subs {
		select {
		case subscriber <- msg:
		default:
			// A slow client must never stall other clients or the upstream.
			close(subscriber)
			delete(h.subs, subscriber)
		}
	}
	if len(h.subs) == 0 {
		h.cancel()
	}
}

func (s *Server) subscribeStream(u *User, service, secret string, pump func(context.Context, string, func(string, any))) (<-chan homeMessage, func()) {
	// Credential rotation and session-version changes must not share a
	// connection with a previous identity or a different account.
	key := u.Name + "|" + strconv.Itoa(u.Version) + "|" + service + "|" + u.Credentials[service]
	s.streamMu.Lock()
	if s.streamHubs == nil {
		s.streamHubs = make(map[string]*streamHub)
	}
	h := s.streamHubs[key]
	start := false
	var ctx context.Context
	if h == nil {
		var cancel context.CancelFunc
		ctx, cancel = context.WithCancel(context.Background())
		h = &streamHub{cancel: cancel, subs: make(map[chan homeMessage]struct{}), states: make(map[string]homeEntity)}
		s.streamHubs[key] = h
		start = true
	}
	ch := make(chan homeMessage, 64)
	h.mu.Lock()
	if h.snapshot != nil {
		ch <- *h.snapshot
	}
	if h.metadata != nil {
		ch <- *h.metadata
	}
	h.subs[ch] = struct{}{}
	h.mu.Unlock()
	s.streamMu.Unlock()

	if start {
		go func() {
			pump(ctx, secret, h.publish)
			s.streamMu.Lock()
			if s.streamHubs[key] == h {
				delete(s.streamHubs, key)
			}
			h.mu.Lock()
			h.closed = true
			for subscriber := range h.subs {
				close(subscriber)
			}
			h.subs = nil
			h.mu.Unlock()
			s.streamMu.Unlock()
		}()
	}
	unsubscribe := func() {
		s.streamMu.Lock()
		h.mu.Lock()
		if _, ok := h.subs[ch]; ok {
			delete(h.subs, ch)
			close(ch)
			if len(h.subs) == 0 {
				h.cancel()
				if s.streamHubs[key] == h {
					delete(s.streamHubs, key)
				}
			}
		}
		h.mu.Unlock()
		s.streamMu.Unlock()
	}
	return ch, unsubscribe
}

func (s *Server) subscribeHome(u *User, secret string) (<-chan homeMessage, func()) {
	return s.subscribeStream(u, "homeassistant", secret, s.pumpHomeEvents)
}

func (s *Server) serveHomeEvents(w http.ResponseWriter, r *http.Request) {
	user := s.session(r)
	if !hasPage(user, "home") {
		failure(w, http.StatusForbidden, "Access denied")
		return
	}
	encrypted := user.Credentials["homeassistant"]
	secret, err := s.decrypt(encrypted)
	if err != nil || secret == "" {
		failure(w, http.StatusConflict, "Home Assistant not connected")
		return
	}
	flush, ok := w.(http.Flusher)
	if !ok {
		failure(w, http.StatusInternalServerError, "Streaming unavailable")
		return
	}
	stream, unsubscribe := s.subscribeHome(user, secret)
	defer unsubscribe()
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "retry: 3000\n\n")
	flush.Flush()
	heartbeat := time.NewTicker(15 * time.Second)
	defer heartbeat.Stop()
	authorized := func() bool {
		current := s.session(r)
		return hasPage(current, "home") &&
			current.Name == user.Name &&
			current.Version == user.Version &&
			current.Credentials["homeassistant"] == encrypted
	}
	for {
		select {
		case <-r.Context().Done():
			return
		case <-heartbeat.C:
			if !authorized() {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "unauthorized"})
				return
			}
			if _, err := fmt.Fprint(w, ": keep-alive\n\n"); err != nil {
				return
			}
			flush.Flush()
		case msg, ok := <-stream:
			if !ok {
				return
			}
			if !authorized() {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "unauthorized"})
				return
			}
			if err := sendHomeEvent(w, flush, msg.kind, msg.data); err != nil {
				return
			}
			if msg.kind == "status" {
				return
			}
		}
	}
}
