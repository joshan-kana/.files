package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

type arrQueue struct {
	TotalRecords int `json:"totalRecords"`
	Records      []struct {
		ID           int     `json:"id"`
		Title        string  `json:"title"`
		Status       string  `json:"status"`
		Sizeleft     float64 `json:"sizeleft"`
		Size         float64 `json:"size"`
		Timeleft     string  `json:"timeleft"`
		ErrorMessage string  `json:"errorMessage"`
	} `json:"records"`
}

func (s *Server) fetchArrQueue(u *User, service string) (arrQueue, error) {
	b, err := s.fetch(u, service, "/api/v3/queue?page=1&pageSize=50&includeUnknownSeriesItems=true")
	if err != nil {
		return arrQueue{}, err
	}
	var result arrQueue
	if err := json.Unmarshal(b, &result); err != nil {
		return arrQueue{}, errors.New("invalid queue response")
	}
	if result.Records == nil {
		result.Records = make([]struct {
			ID           int     `json:"id"`
			Title        string  `json:"title"`
			Status       string  `json:"status"`
			Sizeleft     float64 `json:"sizeleft"`
			Size         float64 `json:"size"`
			Timeleft     string  `json:"timeleft"`
			ErrorMessage string  `json:"errorMessage"`
		}, 0)
	}
	return result, nil
}

// Sonarr and Radarr use ASP.NET Core SignalR for application notifications.
// A connection is negotiated once; subsequent queue reads follow actual
// notifications rather than a recurring fetch timer.
func arrSignalRConnect(ctx context.Context, base, token string) (*websocket.Conn, error) {
	endpoint, err := url.Parse(base)
	if err != nil || (endpoint.Scheme != "http" && endpoint.Scheme != "https") {
		return nil, errors.New("invalid Arr endpoint")
	}
	negotiate := *endpoint
	negotiate.Path = "/signalr/messages/negotiate"
	q := url.Values{"negotiateVersion": []string{"1"}}
	negotiate.RawQuery = q.Encode()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, negotiate.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-Api-Key", token)
	client := &http.Client{Timeout: 6 * time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
	resp, err := client.Do(req)
	if err != nil {
		return nil, errors.New("Arr SignalR negotiation unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, errors.New("Arr SignalR negotiation rejected")
	}
	var result struct {
		ConnectionToken string `json:"connectionToken"`
		ConnectionID    string `json:"connectionId"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<16)).Decode(&result); err != nil {
		return nil, errors.New("invalid Arr SignalR negotiation")
	}
	id := result.ConnectionToken
	if id == "" {
		id = result.ConnectionID
	}
	if id == "" || len(id) > 1024 {
		return nil, errors.New("missing Arr SignalR connection")
	}
	socket := *endpoint
	if socket.Scheme == "http" {
		socket.Scheme = "ws"
	} else {
		socket.Scheme = "wss"
	}
	socket.Path = "/signalr/messages"
	socket.RawQuery = url.Values{"id": []string{id}, "access_token": []string{token}}.Encode()
	headers := http.Header{"X-Api-Key": []string{token}}
	conn, _, err := (&websocket.Dialer{HandshakeTimeout: 6 * time.Second}).DialContext(ctx, socket.String(), headers)
	if err != nil {
		return nil, errors.New("Arr SignalR WebSocket unavailable")
	}
	conn.SetReadLimit(2 << 20)
	conn.SetReadDeadline(time.Now().Add(8 * time.Second))
	if err := conn.WriteMessage(websocket.TextMessage, []byte("{\"protocol\":\"json\",\"version\":1}\x1e")); err != nil {
		conn.Close()
		return nil, err
	}
	_, handshake, err := conn.ReadMessage()
	if err != nil {
		conn.Close()
		return nil, errors.New("Arr SignalR handshake failed")
	}
	frames := bytes.Split(handshake, []byte{0x1e})
	if len(frames) < 2 {
		conn.Close()
		return nil, errors.New("invalid Arr SignalR handshake")
	}
	var accepted struct {
		Error string `json:"error"`
	}
	if json.Unmarshal(frames[0], &accepted) != nil || accepted.Error != "" {
		conn.Close()
		return nil, errors.New("Arr SignalR subscription rejected")
	}
	conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	return conn, nil
}

func arrSignalRNotification(frame []byte) bool {
	var event struct {
		Type      int    `json:"type"`
		Target    string `json:"target"`
		Arguments []struct {
			Name string `json:"name"`
		} `json:"arguments"`
	}
	if json.Unmarshal(frame, &event) != nil || event.Type != 1 || !strings.EqualFold(event.Target, "receiveMessage") {
		return false
	}
	// No assumptions about the type of item: queue state can be changed
	// by a download, import, series, movie, history or command event.
	return true
}

func (s *Server) pumpArrEvents(ctx context.Context, u *User, service, secret string, emit func(string, any)) {
	conn, err := arrSignalRConnect(ctx, upstreams[service], secret)
	if err != nil {
		emit("status", map[string]string{"state": "unavailable"})
		return
	}
	defer conn.Close()
	socketDone := make(chan struct{})
	defer close(socketDone)
	go func() {
		select {
		case <-ctx.Done():
			conn.Close()
		case <-socketDone:
		}
	}()
	queue, err := s.fetchArrQueue(u, service)
	if err != nil {
		emit("status", map[string]string{"state": "queue-unavailable"})
	} else {
		emit("queue", queue)
	}
	notifications := make(chan struct{}, 1)
	readErrors := make(chan struct{}, 1)
	go func() {
		for {
			conn.SetReadDeadline(time.Now().Add(90 * time.Second))
			_, frame, err := conn.ReadMessage()
			if err != nil {
				readErrors <- struct{}{}
				return
			}
			for _, packet := range bytes.Split(frame, []byte{0x1e}) {
				if len(packet) > 0 && arrSignalRNotification(packet) {
					select {
					case notifications <- struct{}{}:
					default:
					}
				}
			}
		}
	}()
	heartbeat := time.NewTicker(25 * time.Second)
	defer heartbeat.Stop()
	var debounce *time.Timer
	var fire <-chan time.Time
	defer func() {
		if debounce != nil {
			debounce.Stop()
		}
	}()
	for {
		select {
		case <-ctx.Done():
			return
		case <-readErrors:
			emit("status", map[string]string{"state": "offline"})
			return
		case <-heartbeat.C:
			if conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(2*time.Second)) != nil {
				return
			}
		case <-notifications:
			if debounce == nil {
				debounce = time.NewTimer(200 * time.Millisecond)
			} else {
				if !debounce.Stop() {
					select {
					case <-debounce.C:
					default:
					}
				}
				debounce.Reset(200 * time.Millisecond)
			}
			fire = debounce.C
		case <-fire:
			fire = nil
			queue, err := s.fetchArrQueue(u, service)
			if err != nil {
				emit("status", map[string]string{"state": "queue-unavailable"})
			} else {
				emit("queue", queue)
			}
		}
	}
}

func (s *Server) serveArrEvents(w http.ResponseWriter, r *http.Request) {
	u := s.session(r)
	if !hasPage(u, "media") {
		failure(w, http.StatusForbidden, "Access denied")
		return
	}
	service := r.PathValue("service")
	if service != "sonarr" && service != "radarr" {
		failure(w, http.StatusNotFound, "Not found")
		return
	}
	encrypted := u.Credentials[service]
	secret, err := s.decrypt(encrypted)
	if err != nil || secret == "" {
		failure(w, http.StatusConflict, "Media manager not connected")
		return
	}
	flush, ok := w.(http.Flusher)
	if !ok {
		failure(w, http.StatusInternalServerError, "Streaming unavailable")
		return
	}
	pump := func(ctx context.Context, _ string, emit func(string, any)) {
		s.pumpArrEvents(ctx, u, service, secret, emit)
	}
	stream, unsubscribe := s.subscribeStream(u, service, secret, pump)
	defer unsubscribe()
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("retry: 15000\n\n"))
	flush.Flush()
	heartbeat := time.NewTicker(15 * time.Second)
	defer heartbeat.Stop()
	authorized := func() bool {
		current := s.session(r)
		return hasPage(current, "media") &&
			current.Name == u.Name &&
			current.Version == u.Version &&
			current.Credentials[service] == encrypted
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
			if _, err := w.Write([]byte(": keep-alive\n\n")); err != nil {
				return
			}
			flush.Flush()
		case message, ok := <-stream:
			if !ok {
				return
			}
			if !authorized() {
				sendHomeEvent(w, flush, "status", map[string]string{"state": "unauthorized"})
				return
			}
			if err := sendHomeEvent(w, flush, message.kind, message.data); err != nil {
				return
			}
			if message.kind == "status" && string(message.data) != "" {
				// A disconnected upstream will be re-established by EventSource.
				return
			}
		}
	}
}
