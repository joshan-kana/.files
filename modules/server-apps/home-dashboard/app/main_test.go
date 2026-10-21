package main

import (
	"bytes"
	"encoding/json"
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
	status(t, req(s, "GET", "/api/health", nil, guestCookie, ""), 403)
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
