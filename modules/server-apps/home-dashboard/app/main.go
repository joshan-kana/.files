package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed static/*
var assets embed.FS

var pages = []string{"overview", "home", "media", "apps"}
var credentialPages = map[string]string{"homeassistant": "home", "sonarr": "media", "radarr": "media"}
var upstreams = map[string]string{"homeassistant": "http://127.0.0.1:8123", "sonarr": "http://127.0.0.1:8989", "radarr": "http://127.0.0.1:7878"}
var entityPattern = regexp.MustCompile(`^(light|switch|fan|input_boolean|climate|cover|scene|sensor|binary_sensor|button|number|select|media_player)\.[a-z0-9_]+$`)

type User struct {
	Name        string            `json:"name"`
	Salt        string            `json:"salt"`
	Password    string            `json:"password"`
	Iterations  int               `json:"iterations"`
	Admin       bool              `json:"admin"`
	Theme       string            `json:"theme,omitempty"`
	Accent      string            `json:"accent,omitempty"`
	Enabled     bool              `json:"enabled"`
	Pages       map[string]bool   `json:"pages"`
	Credentials map[string]string `json:"credentials"`
	Version     int               `json:"version"`
	Favorites   []string          `json:"favorites,omitempty"`
	Rooms       map[string]string `json:"rooms,omitempty"`
	Hand        string            `json:"hand,omitempty"`
}
type Database struct {
	Users map[string]*User `json:"users"`
}
type Server struct {
	mu     sync.Mutex
	data   Database
	dir    string
	key    []byte
	client *http.Client
}

func random(n int) []byte {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return b
}
func randHex(n int) string { return hex.EncodeToString(random(n)) }
func (s *Server) save() error {
	data, err := json.MarshalIndent(s.data, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(s.dir, ".users-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if err = tmp.Chmod(0600); err != nil {
		tmp.Close()
		return err
	}
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), filepath.Join(s.dir, "users.json"))
}
func newServer(dir string) (*Server, error) {
	if err := os.MkdirAll(dir, 0700); err != nil {
		return nil, err
	}
	kpath := filepath.Join(dir, "master.key")
	key, err := os.ReadFile(kpath)
	if errors.Is(err, os.ErrNotExist) {
		f, e := os.OpenFile(kpath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if e != nil {
			return nil, e
		}
		key = random(32)
		_, err = f.Write(key)
		if closeErr := f.Close(); err == nil {
			err = closeErr
		}
	}
	if err != nil {
		return nil, err
	}
	if len(key) != 32 {
		return nil, errors.New("invalid master key")
	}
	s := &Server{dir: dir, key: key, data: Database{Users: map[string]*User{}}, client: &http.Client{Timeout: 5 * time.Second}}
	b, err := os.ReadFile(filepath.Join(dir, "users.json"))
	if err == nil {
		if err = json.Unmarshal(b, &s.data); err != nil {
			return nil, err
		}
	} else if !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	if s.data.Users == nil {
		s.data.Users = map[string]*User{}
	}
	return s, nil
}
func hashPassword(password string, salt []byte, iter int) string {
	hash, err := pbkdf2.Key(sha256.New, password, salt, iter, 32)
	if err != nil {
		panic(err)
	}
	return hex.EncodeToString(hash)
}
func setPassword(u *User, password string) {
	salt := random(16)
	u.Salt = hex.EncodeToString(salt)
	u.Iterations = 310000
	u.Password = hashPassword(password, salt, u.Iterations)
	u.Version++
}
func verifyPassword(u *User, password string) bool {
	salt, err := hex.DecodeString(u.Salt)
	if err != nil || u.Iterations < 100000 {
		return false
	}
	expected, err := hex.DecodeString(u.Password)
	if err != nil {
		return false
	}
	actual, err := hex.DecodeString(hashPassword(password, salt, u.Iterations))
	return err == nil && subtle.ConstantTimeCompare(expected, actual) == 1
}
func (s *Server) encrypt(value string) string {
	block, err := aes.NewCipher(s.key)
	if err != nil {
		panic(err)
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		panic(err)
	}
	nonce := random(aead.NonceSize())
	ciphertext := aead.Seal(nonce, nonce, []byte(value), nil)
	return base64.RawURLEncoding.EncodeToString(ciphertext)
}
func (s *Server) decrypt(value string) (string, error) {
	b, err := base64.RawURLEncoding.DecodeString(value)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return "", err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(b) < aead.NonceSize() {
		return "", errors.New("short ciphertext")
	}
	p, err := aead.Open(nil, b[:aead.NonceSize()], b[aead.NonceSize():], nil)
	return string(p), err
}
func (s *Server) token(u *User) string {
	msg := u.Name + "|" + strconv.FormatInt(time.Now().Add(24*time.Hour).Unix(), 10) + "|" + strconv.Itoa(u.Version)
	mac := hmac.New(sha256.New, s.key)
	mac.Write([]byte("session:" + msg))
	return base64.RawURLEncoding.EncodeToString([]byte(msg)) + "." + hex.EncodeToString(mac.Sum(nil))
}
func (s *Server) session(r *http.Request) *User {
	cookie, err := r.Cookie("session")
	if err != nil {
		return nil
	}
	parts := strings.Split(cookie.Value, ".")
	if len(parts) != 2 {
		return nil
	}
	msg, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil
	}
	sig, err := hex.DecodeString(parts[1])
	if err != nil {
		return nil
	}
	mac := hmac.New(sha256.New, s.key)
	mac.Write([]byte("session:" + string(msg)))
	if !hmac.Equal(mac.Sum(nil), sig) {
		return nil
	}
	fields := strings.Split(string(msg), "|")
	if len(fields) != 3 {
		return nil
	}
	until, err := strconv.ParseInt(fields[1], 10, 64)
	if err != nil || time.Now().Unix() > until {
		return nil
	}
	version, err := strconv.Atoi(fields[2])
	if err != nil {
		return nil
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	u := s.data.Users[fields[0]]
	if u == nil || !u.Enabled || u.Version != version {
		return nil
	}
	copy := *u
	copy.Pages = map[string]bool{}
	for k, v := range u.Pages {
		copy.Pages[k] = v
	}
	copy.Favorites = append([]string(nil), u.Favorites...)
	copy.Rooms = map[string]string{}
	for k, v := range u.Rooms {
		copy.Rooms[k] = v
	}
	copy.Credentials = map[string]string{}
	for k, v := range u.Credentials {
		copy.Credentials[k] = v
	}
	return &copy
}
func (s *Server) cookie(w http.ResponseWriter, r *http.Request, u *User) {
	secure := os.Getenv("DASHBOARD_PUBLIC_ORIGIN") != "" || r.TLS != nil || (r.Header.Get("X-Forwarded-Proto") == "https" && (r.RemoteAddr == "127.0.0.1" || strings.HasPrefix(r.RemoteAddr, "127.0.0.1:")))
	http.SetCookie(w, &http.Cookie{Name: "session", Value: s.token(u), Path: "/", MaxAge: 86400, HttpOnly: true, Secure: secure, SameSite: http.SameSiteStrictMode})
}
func jsonResponse(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
func failure(w http.ResponseWriter, status int, msg string) {
	jsonResponse(w, status, map[string]string{"error": msg})
}
func bodyJSON(r *http.Request, out any) error {
	if !strings.HasPrefix(r.Header.Get("Content-Type"), "application/json") {
		return errors.New("expected JSON")
	}
	r.Body = http.MaxBytesReader(nil, r.Body, 65536)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(out); err != nil {
		return err
	}
	var extra any
	if dec.Decode(&extra) != io.EOF {
		return errors.New("extra JSON")
	}
	return nil
}
func allowed(u *User, page string) bool { return u != nil && (u.Admin || u.Pages[page]) }
func hasPage(u *User, page string) bool { return slices.Contains(pages, page) && allowed(u, page) }
func method(w http.ResponseWriter, r *http.Request, want string) bool {
	if r.Method != want {
		w.Header().Set("Allow", want)
		failure(w, 405, "Method not allowed")
		return false
	}
	return true
}

var availableThemes = []string{"carbon", "midnight", "forest", "plum"}
var availableAccents = []string{"mint", "cyan", "violet", "amber", "coral"}

func appearance(value string, options []string) string {
	if slices.Contains(options, value) {
		return value
	}
	return options[0]
}

func (s *Server) me(u *User) any {
	enabled := map[string]bool{}
	for _, p := range pages {
		enabled[p] = allowed(u, p)
	}
	creds := map[string]bool{}
	for k, p := range credentialPages {
		if allowed(u, p) {
			creds[k] = u.Credentials[k] != ""
		}
	}
	return map[string]any{"name": u.Name, "admin": u.Admin, "pages": enabled, "credentials": creds, "theme": appearance(u.Theme, availableThemes), "accent": appearance(u.Accent, availableAccents), "favorites": append([]string{}, u.Favorites...), "rooms": u.Rooms, "hand": appearance(u.Hand, []string{"right", "left"})}
}
func csrf(r *http.Request) bool {
	origin := r.Header.Get("Origin")
	if origin == "" {
		return false
	}
	parsed, err := url.Parse(origin)
	if err != nil {
		return false
	}
	if configured := os.Getenv("DASHBOARD_PUBLIC_ORIGIN"); configured != "" {
		return origin == configured
	}
	return parsed.Host == r.Host && (parsed.Scheme == "http" || parsed.Scheme == "https")
}
func (s *Server) handler() http.Handler {
	mux := http.NewServeMux()
	static, err := fs.Sub(assets, "static")
	if err != nil {
		panic(err)
	}
	mux.Handle("GET /", http.FileServer(http.FS(static)))
	mux.HandleFunc("GET /api/setup/status", func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		ready := len(s.data.Users) > 0
		s.mu.Unlock()
		jsonResponse(w, 200, map[string]bool{"ready": ready})
	})
	mux.HandleFunc("POST /api/setup", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Token    string `json:"token"`
			Username string `json:"username"`
			Password string `json:"password"`
		}
		if bodyJSON(r, &in) != nil {
			failure(w, 400, "Invalid request")
			return
		}
		if !validName(in.Username) || len(in.Password) < 12 {
			failure(w, 400, "Use a valid username and a password of at least 12 characters")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if len(s.data.Users) != 0 {
			failure(w, 409, "Already configured")
			return
		}
		secret, err := os.ReadFile(filepath.Join(s.dir, "setup-token"))
		if err != nil || subtle.ConstantTimeCompare([]byte(strings.TrimSpace(string(secret))), []byte(in.Token)) != 1 {
			failure(w, 403, "Incorrect setup token")
			return
		}
		u := &User{Name: in.Username, Enabled: true, Admin: true, Pages: map[string]bool{}, Credentials: map[string]string{}}
		setPassword(u, in.Password)
		s.data.Users[u.Name] = u
		if err = s.save(); err != nil {
			delete(s.data.Users, u.Name)
			failure(w, 500, "Could not save account")
			return
		}
		os.Remove(filepath.Join(s.dir, "setup-token"))
		s.cookie(w, r, u)
		jsonResponse(w, 201, s.me(u))
	})
	mux.HandleFunc("POST /api/login", func(w http.ResponseWriter, r *http.Request) {
		var in struct {
			Username string `json:"username"`
			Password string `json:"password"`
		}
		if bodyJSON(r, &in) != nil {
			failure(w, 400, "Invalid request")
			return
		}
		s.mu.Lock()
		u := s.data.Users[strings.TrimSpace(in.Username)]
		var copy *User
		if u != nil {
			v := *u
			copy = &v
		}
		s.mu.Unlock()
		if copy == nil || !copy.Enabled || !verifyPassword(copy, in.Password) {
			failure(w, 401, "Invalid credentials")
			return
		}
		s.cookie(w, r, copy)
		jsonResponse(w, 200, s.me(copy))
	})
	mux.HandleFunc("POST /api/logout", func(w http.ResponseWriter, r *http.Request) {
		http.SetCookie(w, &http.Cookie{Name: "session", Value: "", Path: "/", MaxAge: -1, HttpOnly: true, SameSite: http.SameSiteStrictMode})
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /api/session", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		jsonResponse(w, 200, s.me(u))
	})
	mux.HandleFunc("GET /api/catalog", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		entries := []map[string]string{}
		for _, a := range catalog {
			if allowed(u, "apps") || allowed(u, a.Page) {
				entries = append(entries, map[string]string{"id": a.ID, "name": a.Name, "category": a.Category, "url": a.URL, "page": a.Page})
			}
		}
		jsonResponse(w, 200, entries)
	})
	mux.HandleFunc("GET /api/ha/entities", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "home") {
			failure(w, 403, "Access denied")
			return
		}
		b, err := s.fetch(u, "homeassistant", "/api/states")
		if err != nil {
			failure(w, 502, err.Error())
			return
		}
		var raw []struct {
			EntityID   string         `json:"entity_id"`
			State      string         `json:"state"`
			Attributes map[string]any `json:"attributes"`
		}
		if json.Unmarshal(b, &raw) != nil {
			failure(w, 502, "Invalid Home Assistant response")
			return
		}
		results := []any{}
		for _, e := range raw {
			if entityPattern.MatchString(e.EntityID) {
				results = append(results, e)
			}
		}
		jsonResponse(w, 200, results)
	})
	mux.HandleFunc("GET /api/ha/areas", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "home") {
			failure(w, 403, "Access denied")
			return
		}
		// Home Assistant resolves the actual area registry, including device-derived areas.
		// When a template is unavailable, rooms remain manually assignable per account.
		template := `{% set ns = namespace(items=[]) %}{% for e in states if e.domain in ['light','switch','fan','input_boolean','climate','cover','scene','sensor','binary_sensor','button','number','select','media_player'] %}{% set room = area_name(e.entity_id) %}{% if room %}{% set ns.items = ns.items + [{'entity_id': e.entity_id, 'room': room}] %}{% endif %}{% endfor %}{{ ns.items | tojson }}`
		body, _ := json.Marshal(map[string]string{"template": template})
		result, err := s.request(u, "homeassistant", "POST", "/api/template", body)
		if err != nil {
			jsonResponse(w, 200, map[string]string{})
			return
		}
		var rooms []struct {
			EntityID string `json:"entity_id"`
			Room     string `json:"room"`
		}
		if json.Unmarshal(result, &rooms) != nil {
			jsonResponse(w, 200, map[string]string{})
			return
		}
		filtered := map[string]string{}
		for _, entry := range rooms {
			if entityPattern.MatchString(entry.EntityID) && len(entry.Room) <= 60 {
				filtered[entry.EntityID] = entry.Room
			}
		}
		jsonResponse(w, 200, filtered)
	})
	mux.HandleFunc("GET /api/ha/devices", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "home") {
			failure(w, 403, "Access denied")
			return
		}
		// Resolve Home Assistant's actual entity-to-device relationships. The result
		// contains only display metadata and never exposes the upstream token.
		const template = `{% set ns = namespace(items=[]) %}{% for e in states if e.domain in ['light','switch','fan','input_boolean','climate','cover','scene','sensor','binary_sensor','button','number','select','media_player'] %}{% set id = device_id(e.entity_id) %}{% if id %}{% set name = device_name(id) or id %}{% set room = area_name(e.entity_id) or '' %}{% set model = device_attr(id, 'model') or '' %}{% set ns.items = ns.items + [{'entity_id': e.entity_id, 'id': id, 'name': name, 'room': room, 'model': model}] %}{% endif %}{% endfor %}{{ ns.items | tojson }}`
		body, _ := json.Marshal(map[string]string{"template": template})
		result, err := s.request(u, "homeassistant", "POST", "/api/template", body)
		if err != nil {
			failure(w, 502, "Home Assistant device registry unavailable")
			return
		}
		var raw []struct {
			EntityID string `json:"entity_id"`
			ID       string `json:"id"`
			Name     string `json:"name"`
			Room     string `json:"room"`
			Model    string `json:"model"`
		}
		if json.Unmarshal(result, &raw) != nil {
			failure(w, 502, "Invalid device registry response")
			return
		}
		filtered := make(map[string]any)
		for _, device := range raw {
			if entityPattern.MatchString(device.EntityID) && len(device.ID) <= 128 && len(device.Name) <= 128 && len(device.Room) <= 80 && len(device.Model) <= 128 {
				filtered[device.EntityID] = map[string]string{"id": device.ID, "name": device.Name, "room": device.Room, "model": device.Model}
			}
		}
		jsonResponse(w, 200, filtered)
	})
	mux.HandleFunc("PUT /api/profile/home", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "home") {
			failure(w, 403, "Access denied")
			return
		}
		var in struct {
			Favorites []string          `json:"favorites"`
			Rooms     map[string]string `json:"rooms"`
			Hand      string            `json:"hand"`
		}
		if bodyJSON(r, &in) != nil || len(in.Favorites) > 128 || len(in.Rooms) > 256 || (in.Hand != "right" && in.Hand != "left") {
			failure(w, 400, "Invalid home preferences")
			return
		}
		for _, id := range in.Favorites {
			if !entityPattern.MatchString(id) {
				failure(w, 400, "Invalid favorite")
				return
			}
		}
		for id, room := range in.Rooms {
			if !entityPattern.MatchString(id) || len(room) > 48 || strings.TrimSpace(room) == "" {
				failure(w, 400, "Invalid room")
				return
			}
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		target := s.data.Users[u.Name]
		if target == nil || !target.Enabled {
			failure(w, 401, "Account unavailable")
			return
		}
		oldFavorites, oldRooms, oldHand := target.Favorites, target.Rooms, target.Hand
		target.Favorites, target.Rooms, target.Hand = in.Favorites, in.Rooms, in.Hand
		if err := s.save(); err != nil {
			target.Favorites, target.Rooms, target.Hand = oldFavorites, oldRooms, oldHand
			failure(w, 500, "Could not save preferences")
			return
		}
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("POST /api/ha/action", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "home") {
			failure(w, 403, "Access denied")
			return
		}
		var in struct {
			Entity      string  `json:"entity"`
			Action      string  `json:"action"`
			Brightness  int     `json:"brightness"`
			Percentage  int     `json:"percentage"`
			Temperature float64 `json:"temperature"`
			Option      string  `json:"option"`
			Value       float64 `json:"value"`
		}
		if bodyJSON(r, &in) != nil || !entityPattern.MatchString(in.Entity) {
			failure(w, 400, "Invalid entity")
			return
		}
		domain := strings.Split(in.Entity, ".")[0]
		action := in.Action
		payload := map[string]any{"entity_id": in.Entity}
		switch domain {
		case "light", "switch", "fan", "input_boolean":
			if action == "brightness" && domain == "light" && in.Brightness >= 1 && in.Brightness <= 100 {
				action = "turn_on"
				payload["brightness_pct"] = in.Brightness
			} else if action == "percentage" && domain == "fan" && in.Percentage >= 0 && in.Percentage <= 100 {
				action = "set_percentage"
				payload["percentage"] = in.Percentage
			} else if action != "toggle" && action != "turn_on" && action != "turn_off" {
				failure(w, 400, "Action not supported")
				return
			}
		case "cover":
			if action != "open_cover" && action != "close_cover" && action != "stop_cover" {
				failure(w, 400, "Action not supported")
				return
			}
		case "climate":
			if action != "set_temperature" || in.Temperature < 10 || in.Temperature > 35 {
				failure(w, 400, "Action not supported")
				return
			}
			payload["temperature"] = in.Temperature
		case "scene":
			if action != "turn_on" {
				failure(w, 400, "Action not supported")
				return
			}
		case "button":
			if action != "press" {
				failure(w, 400, "Action not supported")
				return
			}
		case "select":
			if action != "select_option" || len(in.Option) == 0 || len(in.Option) > 128 {
				failure(w, 400, "Invalid option")
				return
			}
			payload["option"] = in.Option
		case "number":
			if action != "set_value" || in.Value < -10000 || in.Value > 10000 || math.IsNaN(in.Value) || math.IsInf(in.Value, 0) {
				failure(w, 400, "Invalid value")
				return
			}
			payload["value"] = in.Value
		case "media_player":
			if action != "media_play_pause" && action != "media_stop" && action != "volume_up" && action != "volume_down" {
				failure(w, 400, "Action not supported")
				return
			}
		default:
			failure(w, 400, "Action not supported")
			return
		}
		b, _ := json.Marshal(payload)
		_, err := s.request(u, "homeassistant", "POST", "/api/services/"+domain+"/"+action, b)
		if err != nil {
			failure(w, 502, err.Error())
			return
		}
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /api/arr/{service}", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if !hasPage(u, "media") {
			failure(w, 403, "Access denied")
			return
		}
		service := r.PathValue("service")
		if service != "sonarr" && service != "radarr" {
			failure(w, 404, "Not found")
			return
		}
		b, err := s.fetch(u, service, "/api/v3/queue?page=1&pageSize=50&includeUnknownSeriesItems=true")
		if err != nil {
			failure(w, 502, err.Error())
			return
		}
		var raw struct {
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
		if json.Unmarshal(b, &raw) != nil {
			failure(w, 502, "Invalid Arr response")
			return
		}
		jsonResponse(w, 200, raw)
	})
	mux.HandleFunc("GET /api/credentials", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		jsonResponse(w, 200, s.me(u))
	})
	mux.HandleFunc("PUT /api/credentials/{service}", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		service := r.PathValue("service")
		p, ok := credentialPages[service]
		if !ok || !allowed(u, p) {
			failure(w, 403, "Access denied")
			return
		}
		var in struct {
			Token string `json:"token"`
		}
		if bodyJSON(r, &in) != nil || len(in.Token) > 4096 {
			failure(w, 400, "Invalid credential")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		target := s.data.Users[u.Name]
		if target == nil {
			failure(w, 401, "Account unavailable")
			return
		}
		if target.Credentials == nil {
			target.Credentials = map[string]string{}
		}
		old := target.Credentials[service]
		if in.Token == "" {
			delete(target.Credentials, service)
		} else {
			target.Credentials[service] = s.encrypt(strings.TrimSpace(in.Token))
		}
		if err := s.save(); err != nil {
			target.Credentials[service] = old
			failure(w, 500, "Could not save credential")
			return
		}
		jsonResponse(w, 200, map[string]bool{"connected": target.Credentials[service] != ""})
	})
	mux.HandleFunc("PUT /api/profile/appearance", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		var in struct {
			Theme  string `json:"theme"`
			Accent string `json:"accent"`
		}
		if bodyJSON(r, &in) != nil || !slices.Contains(availableThemes, in.Theme) || !slices.Contains(availableAccents, in.Accent) {
			failure(w, 400, "Invalid appearance")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		target := s.data.Users[u.Name]
		if target == nil || !target.Enabled {
			failure(w, 401, "Account unavailable")
			return
		}
		previousTheme, previousAccent := target.Theme, target.Accent
		target.Theme, target.Accent = in.Theme, in.Accent
		if err := s.save(); err != nil {
			target.Theme, target.Accent = previousTheme, previousAccent
			failure(w, 500, "Could not save appearance")
			return
		}
		jsonResponse(w, 200, map[string]string{"theme": target.Theme, "accent": target.Accent})
	})
	mux.HandleFunc("POST /api/profile/password", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil {
			failure(w, 401, "Not signed in")
			return
		}
		var in map[string]string
		if bodyJSON(r, &in) != nil || len(in["password"]) < 12 {
			failure(w, 400, "New password must be at least 12 characters")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		target := s.data.Users[u.Name]
		if target == nil || !verifyPassword(target, in["current"]) {
			failure(w, 403, "Incorrect current password")
			return
		}
		old := *target
		setPassword(target, in["password"])
		if err := s.save(); err != nil {
			*target = old
			failure(w, 500, "Could not save password")
			return
		}
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("GET /api/users", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil || !u.Admin {
			failure(w, 403, "Administrator required")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		users := []any{}
		for _, v := range s.data.Users {
			users = append(users, map[string]any{"name": v.Name, "admin": v.Admin, "enabled": v.Enabled, "pages": v.Pages})
		}
		jsonResponse(w, 200, users)
	})
	mux.HandleFunc("POST /api/users", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil || !u.Admin {
			failure(w, 403, "Administrator required")
			return
		}
		var in struct {
			Name     string          `json:"name"`
			Password string          `json:"password"`
			Pages    map[string]bool `json:"pages"`
		}
		if bodyJSON(r, &in) != nil || !validName(in.Name) || len(in.Password) < 12 || !validPages(in.Pages) {
			failure(w, 400, "Invalid account information")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		if s.data.Users[in.Name] != nil {
			failure(w, 409, "User already exists")
			return
		}
		nu := &User{Name: in.Name, Enabled: true, Pages: in.Pages, Credentials: map[string]string{}}
		setPassword(nu, in.Password)
		s.data.Users[in.Name] = nu
		if err := s.save(); err != nil {
			delete(s.data.Users, in.Name)
			failure(w, 500, "Could not save account")
			return
		}
		jsonResponse(w, 201, map[string]any{"name": nu.Name, "pages": nu.Pages})
	})
	mux.HandleFunc("PATCH /api/users/{name}", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil || !u.Admin {
			failure(w, 403, "Administrator required")
			return
		}
		var in struct {
			Pages    *map[string]bool `json:"pages"`
			Enabled  *bool            `json:"enabled"`
			Password string           `json:"password"`
		}
		if bodyJSON(r, &in) != nil || (in.Pages != nil && !validPages(*in.Pages)) || (in.Password != "" && len(in.Password) < 12) {
			failure(w, 400, "Invalid change")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		target := s.data.Users[r.PathValue("name")]
		if target == nil {
			failure(w, 404, "Unknown user")
			return
		}
		if target.Admin && (in.Pages != nil || in.Enabled != nil) {
			failure(w, 400, "Administrator permissions cannot be changed here")
			return
		}
		original := *target
		if in.Pages != nil {
			target.Pages = *in.Pages
		}
		if in.Enabled != nil {
			target.Enabled = *in.Enabled
			target.Version++
		}
		if in.Password != "" {
			setPassword(target, in.Password)
		}
		if err := s.save(); err != nil {
			*target = original
			failure(w, 500, "Could not save account")
			return
		}
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	mux.HandleFunc("DELETE /api/users/{name}", func(w http.ResponseWriter, r *http.Request) {
		u := s.session(r)
		if u == nil || !u.Admin {
			failure(w, 403, "Administrator required")
			return
		}
		s.mu.Lock()
		defer s.mu.Unlock()
		name := r.PathValue("name")
		target := s.data.Users[name]
		if target == nil {
			failure(w, 404, "Unknown user")
			return
		}
		if target.Admin {
			failure(w, 400, "Cannot remove an administrator")
			return
		}
		delete(s.data.Users, name)
		if err := s.save(); err != nil {
			s.data.Users[name] = target
			failure(w, 500, "Could not save account")
			return
		}
		jsonResponse(w, 200, map[string]bool{"ok": true})
	})
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "same-origin")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
		if r.Method != "GET" && r.Method != "HEAD" && !csrf(r) {
			failure(w, 403, "Invalid request origin")
			return
		}
		if strings.HasPrefix(r.URL.Path, "/api/") {
			w.Header().Set("Cache-Control", "no-store")
		}
		mux.ServeHTTP(w, r)
	})
}

var namePattern = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9_-]{2,31}$`)

func validName(s string) bool { return namePattern.MatchString(s) }
func validPages(p map[string]bool) bool {
	for k := range p {
		if !slices.Contains(pages, k) {
			return false
		}
	}
	return true
}
func (s *Server) fetch(u *User, service, path string) ([]byte, error) {
	return s.request(u, service, "GET", path, nil)
}
func (s *Server) request(u *User, service, verb, path string, body []byte) ([]byte, error) {
	endpoint, ok := upstreams[service]
	if !ok {
		return nil, errors.New("Unknown service")
	}
	enc := u.Credentials[service]
	if enc == "" {
		return nil, errors.New("Connect your " + service + " account in Settings")
	}
	token, err := s.decrypt(enc)
	if err != nil {
		return nil, errors.New("Saved credentials unavailable")
	}
	req, err := http.NewRequest(verb, endpoint+path, strings.NewReader(string(body)))
	if err != nil {
		return nil, err
	}
	if service == "homeassistant" {
		req.Header.Set("Authorization", "Bearer "+token)
	} else {
		req.Header.Set("X-Api-Key", token)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	// Fixed loopback upstreams; redirects are never followed to another origin.
	client := *s.client
	client.CheckRedirect = func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return nil, errors.New("Service unavailable")
	}
	defer resp.Body.Close()
	if resp.StatusCode == 401 || resp.StatusCode == 403 {
		return nil, errors.New("Service rejected your credentials")
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("Service returned HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 2<<20))
}

type catalogItem struct{ ID, Name, Category, Page, URL string }

var catalog = []catalogItem{
	{"ha", "Home Assistant", "Smart home", "home", "http://ha.home:8123"},
	{"jellyfin", "Jellyfin", "Media", "media", "http://nixos-server.home:8096"},
	{"sonarr", "Sonarr", "Media", "media", "http://nixos-server.home:8989"},
	{"radarr", "Radarr", "Media", "media", "http://nixos-server.home:7878"},
	{"prowlarr", "Prowlarr", "Media", "media", "http://nixos-server.home:9696"},
	{"bazarr", "Bazarr", "Media", "media", "http://nixos-server.home:6767"},
	{"transmission", "Transmission", "Media", "media", "http://nixos-server.home:9091"},
	{"seerr", "Seerr", "Media", "media", "http://nixos-server.home:5055"},
	{"streamystats", "Streamystats", "Media", "media", "http://nixos-server.home:3013"},
	{"immich", "Immich", "Photos", "apps", "http://nixos-server.home:2283"},
	{"paperless", "Paperless", "Documents", "apps", "http://nixos-server.home:28981"},
	{"n8n", "n8n", "Automation", "apps", "http://n8n.home:5678"},
	{"openwebui", "Open WebUI", "AI", "apps", "http://nixos-server.home:8081"},
	{"computer", "Computer", "AI", "apps", "http://nixos-server.home:8000"},
	{"openclaw", "OpenClaw", "AI", "apps", "https://nixos-server.home:18789"},
	{"gitea", "Gitea", "Development", "apps", "http://nixos-server.home:3000"},
	{"gerrit", "Gerrit", "Development", "apps", "http://nixos-server.home:8787"},
	{"onedev", "OneDev", "Development", "apps", "http://nixos-server.home:6610"},
	{"agentmail", "Agent Mail", "Development", "apps", "http://nixos-server.home:8765/mail/"},
	{"adguard", "AdGuard Home", "Networking", "apps", "http://dns.home:3000"},
	{"technitium", "Technitium DNS", "Networking", "apps", "http://nixos-server.home:5380"},
	{"ntfy", "ntfy", "Automation", "apps", "http://nixos-server.home:2586"},
}

// resetPassword is for a server administrator running as the service owner.
// Stop the service before invoking it, so its in-memory database cannot overwrite the change.
func resetPassword(dir, username string, input io.Reader) error {
	raw, err := io.ReadAll(io.LimitReader(input, 4097))
	if err != nil {
		return err
	}
	if len(raw) > 4096 {
		return errors.New("password too long")
	}
	password := strings.TrimRight(string(raw), "\r\n")
	if len(password) < 12 {
		return errors.New("password must contain at least 12 characters")
	}
	s, err := newServer(dir)
	if err != nil {
		return err
	}
	u := s.data.Users[username]
	if u == nil {
		return errors.New("account not found")
	}
	previous := *u
	setPassword(u, password)
	if err = s.save(); err != nil {
		*u = previous
		return err
	}
	return nil
}

func main() {
	dir := os.Getenv("DASHBOARD_DATA_DIR")
	if dir == "" {
		dir = "./.dashboard-data"
	}
	if len(os.Args) > 1 {
		if len(os.Args) != 3 || os.Args[1] != "reset-password" {
			log.Fatal("usage: home-dashboard reset-password <username> (new password from stdin)")
		}
		if err := resetPassword(dir, os.Args[2], os.Stdin); err != nil {
			log.Fatal(err)
		}
		fmt.Println("Password updated. Restart home-dashboard to load the updated account.")
		return
	}
	s, err := newServer(dir)
	if err != nil {
		log.Fatal(err)
	}
	s.mu.Lock()
	ready := len(s.data.Users) > 0
	s.mu.Unlock()
	if !ready {
		p := filepath.Join(dir, "setup-token")
		if _, err := os.Stat(p); errors.Is(err, os.ErrNotExist) {
			if err = os.WriteFile(p, []byte(randHex(24)+string(byte(10))), 0600); err != nil {
				log.Fatal(err)
			}
		}
		log.Printf("First run: read setup token from %s on the server", p)
	}
	addr := os.Getenv("DASHBOARD_LISTEN")
	if addr == "" {
		addr = "127.0.0.1:8777"
	}
	log.Printf("Home dashboard listening at %s", addr)
	log.Fatal(http.ListenAndServe(addr, s.handler()))
}
