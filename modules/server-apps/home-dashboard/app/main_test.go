package main

import (
	"bytes"
	"encoding/json"
	"github.com/gorilla/websocket"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func testServer(t *testing.T) *Server {
	t.Helper()
	s, err := newServer(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	return s
}
func req(s *Server, verb, path string, body any, cookie string, origin string) *httptest.ResponseRecorder {
	var payload []byte
	if body != nil {
		payload, _ = json.Marshal(body)
	}
	r := httptest.NewRequest(verb, "http://example.test"+path, bytes.NewReader(payload))
	if body != nil {
		r.Header.Set("Content-Type", "application/json")
	}
	if origin != "" {
		r.Header.Set("Origin", origin)
	}
	if cookie != "" {
		r.AddCookie(&http.Cookie{Name: "session", Value: cookie})
	}
	w := httptest.NewRecorder()
	s.handler().ServeHTTP(w, r)
	return w
}
func addUser(s *Server, name string, admin bool, perms map[string]bool) *User {
	u := &User{Name: name, Admin: admin, Enabled: true, Pages: perms, Credentials: map[string]string{}}
	setPassword(u, "password-example-1234")
	s.data.Users[name] = u
	return u
}
func status(t *testing.T, w *httptest.ResponseRecorder, expected int) {
	t.Helper()
	if w.Code != expected {
		t.Fatalf("expected HTTP %d; got HTTP %d: %s", expected, w.Code, w.Body.String())
	}
}
func TestSetupAndLogin(t *testing.T) {
	s := testServer(t)
	if err := os.WriteFile(filepath.Join(s.dir, "setup-token"), []byte("test-bootstrap-token"), 0600); err != nil {
		t.Fatal(err)
	}
	bad := req(s, "POST", "/api/setup", map[string]any{"token": "wrong", "username": "admin", "password": "password-example-1234"}, "", "http://example.test")
	status(t, bad, 403)
	good := req(s, "POST", "/api/setup", map[string]any{"token": "test-bootstrap-token", "username": "admin", "password": "password-example-1234"}, "", "http://example.test")
	status(t, good, 201)
	if len(good.Result().Cookies()) == 0 {
		t.Fatal("setup should sign in")
	}
	if _, err := os.Stat(filepath.Join(s.dir, "setup-token")); !os.IsNotExist(err) {
		t.Fatal("setup token must be removed")
	}
	again := req(s, "POST", "/api/setup", map[string]any{"token": "test-bootstrap-token", "username": "root", "password": "password-example-1234"}, "", "http://example.test")
	status(t, again, 409)
	login := req(s, "POST", "/api/login", map[string]string{"username": "admin", "password": "password-example-1234"}, "", "http://example.test")
	status(t, login, 200)
	invalid := req(s, "POST", "/api/login", map[string]string{"username": "admin", "password": "incorrect"}, "", "http://example.test")
	status(t, invalid, 401)
}
func TestPermissionsAndSessionRevocation(t *testing.T) {
	s := testServer(t)
	admin := addUser(s, "admin", true, nil)
	user := addUser(s, "guest", false, map[string]bool{"media": true})
	guestCookie := s.token(user)
	adminCookie := s.token(admin)
	status(t, req(s, "GET", "/api/ha/entities", nil, guestCookie, ""), 403)
	status(t, req(s, "GET", "/api/ha/areas", nil, guestCookie, ""), 403)
	status(t, req(s, "GET", "/api/users", nil, guestCookie, ""), 403)
	status(t, req(s, "POST", "/api/ha/action", map[string]any{"entity": "light.room", "action": "toggle"}, guestCookie, "http://example.test"), 403)
	status(t, req(s, "GET", "/api/catalog", nil, guestCookie, ""), 200)
	response := req(s, "GET", "/api/catalog", nil, guestCookie, "")
	if strings.Contains(response.Body.String(), "Home Assistant") || strings.Contains(response.Body.String(), "Technitium") {
		t.Fatal("catalog exposed unauthorized pages")
	}
	status(t, req(s, "PATCH", "/api/users/guest", map[string]any{"enabled": false}, adminCookie, "http://example.test"), 200)
	status(t, req(s, "GET", "/api/session", nil, guestCookie, ""), 401)
}
func TestCredentialsArePerUserAndEncrypted(t *testing.T) {
	s := testServer(t)
	a := addUser(s, "alice", false, map[string]bool{"home": true})
	b := addUser(s, "bobby", false, map[string]bool{"home": true})
	secret := "user-private-ha-key-12345"
	status(t, req(s, "PUT", "/api/credentials/homeassistant", map[string]string{"token": secret}, s.token(a), "http://example.test"), 200)
	if s.data.Users["bobby"].Credentials["homeassistant"] != "" {
		t.Fatal("credentials leaked to another account")
	}
	raw, err := os.ReadFile(filepath.Join(s.dir, "users.json"))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(raw, []byte(secret)) {
		t.Fatal("credential stored in plaintext")
	}
	response := req(s, "GET", "/api/session", nil, s.token(a), "")
	if strings.Contains(response.Body.String(), secret) || strings.Contains(response.Body.String(), s.data.Users["alice"].Credentials["homeassistant"]) {
		t.Fatal("credentials leaked in response")
	}
	status(t, req(s, "GET", "/api/credentials", nil, s.token(b), ""), 200)
}
func TestCSRFAndActionAllowlist(t *testing.T) {
	s := testServer(t)
	user := addUser(s, "alice", false, map[string]bool{"home": true})
	c := s.token(user)
	status(t, req(s, "POST", "/api/ha/action", map[string]string{"entity": "light.room", "action": "toggle"}, c, "https://evil.example"), 403)
	status(t, req(s, "POST", "/api/ha/action", map[string]string{"entity": "light.room", "action": "toggle"}, c, ""), 403)
	status(t, req(s, "POST", "/api/ha/action", map[string]string{"entity": "light.room", "action": "restart"}, c, "http://example.test"), 400)
	status(t, req(s, "POST", "/api/ha/action", map[string]string{"entity": "sensor.secret", "action": "toggle"}, c, "http://example.test"), 400)
	status(t, req(s, "PUT", "/api/credentials/sonarr", map[string]string{"token": "secret"}, c, "http://example.test"), 403)
}
func TestFixedUpstreamAndPersonalToken(t *testing.T) {
	upstream := upstreams["homeassistant"]
	defer func() { upstreams["homeassistant"] = upstream }()
	received := make(chan string, 1)
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		received <- r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[]"))
	}))
	defer backend.Close()
	upstreams["homeassistant"] = backend.URL
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	alice.Credentials["homeassistant"] = s.encrypt("alice-own-token")
	status(t, req(s, "GET", "/api/ha/entities", nil, s.token(alice), ""), 200)
	if h := <-received; h != "Bearer alice-own-token" {
		t.Fatalf("wrong account credential used: %s", h)
	}
}

func TestPersonalPasswordChange(t *testing.T) {
	s := testServer(t)
	user := addUser(s, "alice", false, map[string]bool{"home": true})
	token := s.token(user)
	status(t, req(s, "POST", "/api/profile/password", map[string]string{"current": "wrong", "password": "new-password-example"}, token, "http://example.test"), 403)
	status(t, req(s, "POST", "/api/profile/password", map[string]string{"current": "password-example-1234", "password": "new-password-example"}, token, "http://example.test"), 200)
	status(t, req(s, "GET", "/api/session", nil, token, ""), 401)
	status(t, req(s, "POST", "/api/login", map[string]string{"username": "alice", "password": "new-password-example"}, "", "http://example.test"), 200)
}

func TestReverseProxyOriginAndCookie(t *testing.T) {
	t.Setenv("DASHBOARD_PUBLIC_ORIGIN", "https://nixos-server.home:8443")
	s := testServer(t)
	u := addUser(s, "alice", false, map[string]bool{"home": true})
	allowed := req(s, "POST", "/api/logout", nil, s.token(u), "https://nixos-server.home:8443")
	status(t, allowed, 200)
	disallowed := req(s, "POST", "/api/logout", nil, s.token(u), "https://nixos-server.home")
	status(t, disallowed, 403)
	login := req(s, "POST", "/api/login", map[string]string{"username": "alice", "password": "password-example-1234"}, "", "https://nixos-server.home:8443")
	status(t, login, 200)
	if !login.Result().Cookies()[0].Secure {
		t.Fatal("reverse-proxied session cookie must be Secure")
	}
}

func TestAppearanceIsPerUserAndPersistent(t *testing.T) {
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"overview": true})
	bobby := addUser(s, "bobby", false, map[string]bool{"overview": true})
	aliceCookie := s.token(alice)
	before := req(s, "GET", "/api/session", nil, aliceCookie, "")
	status(t, before, 200)
	if !strings.Contains(before.Body.String(), `"theme":"carbon"`) || !strings.Contains(before.Body.String(), `"accent":"mint"`) {
		t.Fatal("older accounts must default to Carbon with mint accents")
	}
	status(t, req(s, "PUT", "/api/profile/appearance", map[string]string{"theme": "midnight", "accent": "violet"}, aliceCookie, "http://example.test"), 200)
	status(t, req(s, "PUT", "/api/profile/appearance", map[string]string{"theme": "invalid", "accent": "mint"}, aliceCookie, "http://example.test"), 400)
	status(t, req(s, "PUT", "/api/profile/appearance", map[string]string{"theme": "forest", "accent": "cyan"}, s.token(bobby), "http://example.test"), 200)
	status(t, req(s, "PUT", "/api/profile/appearance", map[string]string{"theme": "carbon", "accent": "mint"}, "", "http://example.test"), 401)
	if s.data.Users["alice"].Theme != "midnight" || s.data.Users["alice"].Accent != "violet" || s.data.Users["bobby"].Theme != "forest" {
		t.Fatal("appearance was not isolated or validated")
	}
	reloaded, err := newServer(s.dir)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.data.Users["alice"].Theme != "midnight" || reloaded.data.Users["bobby"].Accent != "cyan" {
		t.Fatal("appearance was not saved")
	}
	status(t, req(reloaded, "GET", "/api/session", nil, aliceCookie, ""), 200)
}

func TestLocalRecoveryKeepsAccountAndRevokesOldSession(t *testing.T) {
	srv := testServer(t)
	member := addUser(srv, "person", false, map[string]bool{"home": true})
	cookie := srv.token(member)
	if err := srv.save(); err != nil {
		t.Fatal(err)
	}
	if err := resetPassword(srv.dir, "absent", strings.NewReader("long-new-secret-value\n")); err == nil {
		t.Fatal("missing member must fail")
	}
	if err := resetPassword(srv.dir, "person", strings.NewReader("short\n")); err == nil {
		t.Fatal("short new secret must fail")
	}
	if err := resetPassword(srv.dir, "person", strings.NewReader("long-new-secret-value\n")); err != nil {
		t.Fatal(err)
	}
	latest, err := newServer(srv.dir)
	if err != nil {
		t.Fatal(err)
	}
	if !verifyPassword(latest.data.Users["person"], "long-new-secret-value") {
		t.Fatal("replacement secret not accepted")
	}
	status(t, req(latest, "GET", "/api/session", nil, cookie, ""), 401)
}

func TestCompleteWebAppCatalogAndRemovedInfrastructure(t *testing.T) {
	s := testServer(t)
	user := addUser(s, "member", false, map[string]bool{"apps": true})
	response := req(s, "GET", "/api/catalog", nil, s.token(user), "")
	status(t, response, 200)
	var items []catalogItem
	if err := json.Unmarshal(response.Body.Bytes(), &items); err != nil {
		t.Fatal(err)
	}
	if len(items) < 20 {
		t.Fatalf("expected deployed web interfaces, got %d", len(items))
	}
	names := map[string]bool{}
	for _, item := range items {
		names[item.ID] = true
	}
	for _, name := range []string{"seerr", "streamystats", "gerrit", "onedev", "agentmail", "adguard", "technitium", "ntfy", "computer"} {
		if !names[name] {
			t.Fatalf("missing %s from launcher", name)
		}
	}
	status(t, req(s, "GET", "/api/health", nil, s.token(user), ""), 404)
	member := addUser(s, "media", false, map[string]bool{"media": true})
	mediaList := req(s, "GET", "/api/catalog", nil, s.token(member), "")
	status(t, mediaList, 200)
	if strings.Contains(mediaList.Body.String(), "Technitium") {
		t.Fatal("apps permission should be needed for network console")
	}
	if !strings.Contains(mediaList.Body.String(), "Seerr") {
		t.Fatal("media permission must retain media launchers")
	}
}

func TestHomePreferencesIsolatedAndPersistent(t *testing.T) {
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	bob := addUser(s, "bobby", false, map[string]bool{"home": true})
	cookie := s.token(alice)
	preferences := map[string]any{"favorites": []string{"light.room"}, "rooms": map[string]string{"light.room": "Study"}, "hand": "left"}
	status(t, req(s, "PUT", "/api/profile/home", preferences, cookie, "http://example.test"), 200)
	status(t, req(s, "PUT", "/api/profile/home", map[string]any{"favorites": []string{"sensor.invalid name"}, "rooms": map[string]string{}, "hand": "right"}, cookie, "http://example.test"), 400)
	status(t, req(s, "PUT", "/api/profile/home", preferences, cookie, "https://evil.example"), 403)
	status(t, req(s, "PUT", "/api/profile/home", preferences, s.token(bob), "http://example.test"), 200)
	if alice.Hand != "left" || len(alice.Favorites) != 1 || alice.Rooms["light.room"] != "Study" {
		t.Fatal("preferences not saved")
	}
	reloaded, err := newServer(s.dir)
	if err != nil {
		t.Fatal(err)
	}
	if reloaded.data.Users["alice"].Hand != "left" || reloaded.data.Users["alice"].Rooms["light.room"] != "Study" {
		t.Fatal("preferences not persisted")
	}
	status(t, req(reloaded, "GET", "/api/session", nil, cookie, ""), 200)
}

func TestHomeControlActionAllowlist(t *testing.T) {
	previous := upstreams["homeassistant"]
	defer func() { upstreams["homeassistant"] = previous }()
	type action struct {
		Path string
		Data map[string]any
	}
	calls := []action{}
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var payload map[string]any
		json.NewDecoder(r.Body).Decode(&payload)
		calls = append(calls, action{r.URL.Path, payload})
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[]"))
	}))
	defer backend.Close()
	upstreams["homeassistant"] = backend.URL
	s := testServer(t)
	user := addUser(s, "alice", false, map[string]bool{"home": true})
	user.Credentials["homeassistant"] = s.encrypt("demo-key")
	c := s.token(user)
	for _, input := range []map[string]any{
		{"entity": "light.study", "action": "brightness", "brightness": 74},
		{"entity": "fan.study", "action": "percentage", "percentage": 50},
		{"entity": "climate.office", "action": "set_temperature", "temperature": 22.5},
		{"entity": "cover.blind", "action": "open_cover"},
		{"entity": "scene.relax", "action": "turn_on"},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, c, "http://example.test"), 200)
	}
	if len(calls) != 5 || calls[0].Data["brightness_pct"] != float64(74) || calls[1].Data["percentage"] != float64(50) || calls[2].Data["temperature"] != float64(22.5) || calls[3].Path != "/api/services/cover/open_cover" {
		t.Fatalf("incorrect upstream calls: %+v", calls)
	}
	for _, input := range []map[string]any{
		{"entity": "sensor.temperature", "action": "turn_on"},
		{"entity": "climate.office", "action": "set_temperature", "temperature": 999},
		{"entity": "light.study", "action": "brightness", "brightness": 101},
		{"entity": "cover.blind", "action": "toggle"},
		{"entity": "scene.relax", "action": "turn_off"},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, c, "http://example.test"), 400)
	}
	if len(calls) != 5 {
		t.Fatal("rejected commands reached Home Assistant")
	}
}

func TestDeviceRegistryAndExpandedControlActions(t *testing.T) {
	previous := upstreams["homeassistant"]
	defer func() { upstreams["homeassistant"] = previous }()
	calls := []string{}
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/template" {
			var request struct {
				Template string `json:"template"`
			}
			json.NewDecoder(r.Body).Decode(&request)
			if strings.Contains(request.Template, "ns.items") {
				w.Write([]byte(`[{"entity_id":"light.bambu_chamber","id":"physical-printer","name":"Bambu P2S","room":"Study","model":"P2S"},{"entity_id":"sensor.bambu_temperature","id":"physical-printer","name":"Bambu P2S","room":"Study","model":"P2S"},{"entity_id":"script.untrusted","id":"hidden","name":"Hidden"}]`))
			}
			return
		}
		calls = append(calls, r.URL.Path)
		w.Write([]byte(`[]`))
	}))
	defer backend.Close()
	upstreams["homeassistant"] = backend.URL
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	alice.Credentials["homeassistant"] = s.encrypt("personal-token")
	bobby := addUser(s, "bobby", false, map[string]bool{"media": true})
	status(t, req(s, "GET", "/api/ha/devices", nil, s.token(bobby), ""), 403)
	out := req(s, "GET", "/api/ha/devices", nil, s.token(alice), "")
	status(t, out, 200)
	var registry map[string]struct {
		ID   string `json:"id"`
		Name string `json:"name"`
		Room string `json:"room"`
	}
	if err := json.Unmarshal(out.Body.Bytes(), &registry); err != nil {
		t.Fatal(err)
	}
	if len(registry) != 2 || registry["light.bambu_chamber"].ID != registry["sensor.bambu_temperature"].ID || registry["light.bambu_chamber"].Name != "Bambu P2S" {
		t.Fatalf("device grouping failed: %+v", registry)
	}
	for _, input := range []map[string]any{
		{"entity": "button.bambu_resume", "action": "press"},
		{"entity": "select.bambu_mode", "action": "select_option", "option": "silent"},
		{"entity": "number.bambu_speed", "action": "set_value", "value": 55.5},
		{"entity": "media_player.lounge", "action": "media_play_pause"},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, s.token(alice), "http://example.test"), 200)
	}
	for _, input := range []map[string]any{
		{"entity": "button.bambu_resume", "action": "delete"},
		{"entity": "select.bambu_mode", "action": "select_option", "option": ""},
		{"entity": "number.bambu_speed", "action": "set_value", "value": 999999},
		{"entity": "media_player.lounge", "action": "format_disk"},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, s.token(alice), "http://example.test"), 400)
	}
	if len(calls) != 4 {
		t.Fatalf("disallowed action reached upstream: %+v", calls)
	}
}

func TestFanAndLightCapabilityActions(t *testing.T) {
	previous := upstreams["homeassistant"]
	defer func() { upstreams["homeassistant"] = previous }()
	type call struct {
		Path string
		Body map[string]any
	}
	calls := []call{}
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Error(err)
		}
		calls = append(calls, call{r.URL.Path, body})
		w.Write([]byte(`[]`))
	}))
	defer backend.Close()
	upstreams["homeassistant"] = backend.URL
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	alice.Credentials["homeassistant"] = s.encrypt("token")
	member := s.token(alice)
	for _, input := range []map[string]any{
		{"entity": "fan.bedroom", "action": "percentage", "percentage": 67},
		{"entity": "fan.bedroom", "action": "preset_mode", "preset_mode": "Natural 2"},
		{"entity": "fan.bedroom", "action": "oscillate", "oscillating": true},
		{"entity": "light.wled", "action": "brightness", "brightness": 55},
		{"entity": "light.wled", "action": "color", "color": "#27abfe"},
		{"entity": "light.wled", "action": "color_temp", "kelvin": 3200},
		{"entity": "light.wled", "action": "effect", "effect": "Rainbow"},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, member, "http://example.test"), 200)
	}
	if len(calls) != 7 {
		t.Fatalf("expected 7 upstream actions, got %d", len(calls))
	}
	expected := []string{"/api/services/fan/set_percentage", "/api/services/fan/set_preset_mode", "/api/services/fan/oscillate", "/api/services/light/turn_on", "/api/services/light/turn_on", "/api/services/light/turn_on", "/api/services/light/turn_on"}
	for i, path := range expected {
		if calls[i].Path != path {
			t.Fatalf("request %d path %q expected %q", i, calls[i].Path, path)
		}
	}
	rgb, ok := calls[4].Body["rgb_color"].([]any)
	if !ok || len(rgb) != 3 || rgb[0] != float64(39) || rgb[1] != float64(171) || rgb[2] != float64(254) {
		t.Fatalf("invalid light RGB payload: %#v", calls[4].Body["rgb_color"])
	}
	if calls[5].Body["color_temp_kelvin"] != float64(3200) || calls[2].Body["oscillating"] != true {
		t.Fatal("colour temperature or oscillation missing")
	}
	for _, input := range []map[string]any{
		{"entity": "fan.bedroom", "action": "oscillate"},
		{"entity": "fan.bedroom", "action": "preset_mode", "preset_mode": ""},
		{"entity": "light.wled", "action": "color", "color": "javascript:evil"},
		{"entity": "light.wled", "action": "color_temp", "kelvin": 11000},
		{"entity": "light.wled", "action": "effect", "effect": ""},
	} {
		status(t, req(s, "POST", "/api/ha/action", input, member, "http://example.test"), 400)
	}
	if len(calls) != 7 {
		t.Fatal("invalid actions reached upstream")
	}
}

func TestHomeAreaIconsViaAuthenticatedRegistry(t *testing.T) {
	previous := upstreams["homeassistant"]
	defer func() { upstreams["homeassistant"] = previous }()
	backend := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/websocket" {
			t.Errorf("unexpected API %s", r.URL.Path)
			return
		}
		conn, err := (&websocket.Upgrader{}).Upgrade(w, r, nil)
		if err != nil {
			t.Error(err)
			return
		}
		defer conn.Close()
		conn.WriteJSON(map[string]any{"type": "auth_required"})
		var msg map[string]any
		if err := conn.ReadJSON(&msg); err != nil {
			t.Error(err)
			return
		}
		if msg["type"] != "auth" || msg["access_token"] != "personal-key" {
			t.Error("invalid upstream auth")
			return
		}
		conn.WriteJSON(map[string]any{"type": "auth_ok"})
		if err := conn.ReadJSON(&msg); err != nil {
			t.Error(err)
			return
		}
		if msg["type"] != "config/area_registry/list" {
			t.Error("wrong area registry command")
		}
		conn.WriteJSON(map[string]any{"id": 1, "type": "result", "success": true, "result": []any{
			map[string]any{"name": "Bedroom", "icon": "mdi:bed-king"},
			map[string]any{"name": "Study", "icon": "mdi:chair-rolling"},
			map[string]any{"name": "No Icon", "icon": nil},
		}})
	}))
	defer backend.Close()
	upstreams["homeassistant"] = backend.URL
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	alice.Credentials["homeassistant"] = s.encrypt("personal-key")
	bob := addUser(s, "bob", false, map[string]bool{"media": true})
	status(t, req(s, "GET", "/api/ha/room-icons", nil, s.token(bob), ""), 403)
	out := req(s, "GET", "/api/ha/room-icons", nil, s.token(alice), "")
	status(t, out, 200)
	var icons map[string]string
	if err := json.Unmarshal(out.Body.Bytes(), &icons); err != nil {
		t.Fatal(err)
	}
	if len(icons) != 2 || icons["Bedroom"] != "mdi:bed-king" || icons["Study"] != "mdi:chair-rolling" {
		t.Fatalf("icons not from HA registry: %+v", icons)
	}
	if strings.Contains(out.Body.String(), "personal-key") {
		t.Fatal("upstream token leaked")
	}
}

func TestUnavailableVisibilityPreferencePerAccount(t *testing.T) {
	s := testServer(t)
	alice := addUser(s, "alice", false, map[string]bool{"home": true})
	bob := addUser(s, "bob", false, map[string]bool{"home": true})
	payload := map[string]any{"favorites": []string{}, "rooms": map[string]string{}, "hand": "right", "show_unavailable": true}
	status(t, req(s, "PUT", "/api/profile/home", payload, s.token(alice), "http://example.test"), 200)
	if !alice.ShowUnavailable || bob.ShowUnavailable {
		t.Fatal("per-account visibility preference failed")
	}
	reloaded, err := newServer(s.dir)
	if err != nil {
		t.Fatal(err)
	}
	if !reloaded.data.Users["alice"].ShowUnavailable || reloaded.data.Users["bob"].ShowUnavailable {
		t.Fatal("visibility setting not persisted")
	}
	payload["show_unavailable"] = false
	status(t, req(s, "PUT", "/api/profile/home", payload, s.token(alice), "http://example.test"), 200)
	if alice.ShowUnavailable {
		t.Fatal("cannot hide unavailable entities again")
	}
}
