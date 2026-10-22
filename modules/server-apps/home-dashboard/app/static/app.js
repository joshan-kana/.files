const root = document.getElementById("app");
const navItems = [
  ["overview", "Overview", "grid"],
  ["home", "Smart Home", "home"],
  ["media", "Media", "play"],
  ["infrastructure", "Infrastructure", "server"],
  ["apps", "Applications", "apps"],
  ["settings", "Settings", "settings"],
  ["admin", "Users & Access", "users"],
];
const icons = {
  grid: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  home: '<path d="m3 10 9-7 9 7v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z"/><path d="M9 21v-8h6v8"/>',
  play: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="m10 9 5 3-5 3z"/>',
  server:
    '<rect x="3" y="3" width="18" height="8" rx="2"/><rect x="3" y="13" width="18" height="8" rx="2"/><path d="M7 7h.01M7 17h.01"/>',
  apps: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  settings:
    '<path d="M12 3v2m0 14v2M3 12h2m14 0h2m-4.7-5.3 1.4-1.4M6.7 17.3l-1.4 1.4M5.3 5.3l1.4 1.4m10.6 10.6 1.4 1.4"/><circle cx="12" cy="12" r="5"/>',
  users:
    '<circle cx="9" cy="8" r="3"/><path d="M3 20v-2a6 6 0 0 1 12 0v2M17 5a3 3 0 0 1 0 6m4 9v-2a6 6 0 0 0-4-5.7"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m16 16 5 5"/>',
  sliders:
    '<path d="M4 7h8m5 0h3M4 17h3m5 0h8"/><circle cx="14.5" cy="7" r="2.5"/><circle cx="9.5" cy="17" r="2.5"/>',
  arrow: '<path d="M5 12h14m-6-6 6 6-6 6"/>',
  external:
    '<path d="M14 4h6v6M10 14 20 4"/><path d="M20 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h5"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  bulb: '<path d="M9 18h6m-5 3h4M9 15c-1-1.5-3-3.2-3-6a6 6 0 0 1 12 0c0 2.8-2 4.5-3 6v2H9z"/>',
  power: '<path d="M12 3v9m-5.8-6.5a9 9 0 1 0 11.6 0"/>',
  wind: '<path d="M3 8h12a3 3 0 1 0-3-3M2 12h17a3 3 0 1 1-3 3M3 17h7a3 3 0 1 1-3 3"/>',
  download: '<path d="M12 3v13m-5-5 5 5 5-5M4 19h16v2H4z"/>',
  shield:
    '<path d="M12 2 4 5v6c0 6 4 9 8 11 4-2 8-5 8-11V5z"/><path d="m8 12 3 3 5-6"/>',
  spark:
    '<path d="m12 2 2.8 7.2L22 12l-7.2 2.8L12 22l-2.8-7.2L2 12l7.2-2.8z"/>',
  image:
    '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="m21 15-5-5L5 21"/>',
  doc: '<path d="M6 2h9l4 4v16H6zM14 2v5h5M9 12h7m-7 4h7"/>',
  activity: '<path d="M2 12h4l3-8 5 16 3-8h5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l4 2"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  logout:
    '<path d="M11 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h6m4-4 5-5-5-5m5 5H9"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  check: '<path d="m4 12 5 5L20 6"/>',
  x: '<path d="M5 5 19 19M19 5 5 19"/>',
};
function svg(name) {
  return (
    '<svg viewBox="0 0 24 24" stroke="currentColor" fill="none" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.7" aria-hidden="true">' +
    (icons[name] || icons.apps) +
    "</svg>"
  );
}
function esc(s) {
  return String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
}
const state = {
  me: null,
  ready: true,
  page: "overview",
  catalog: [],
  entities: null,
  health: null,
  arr: {},
  users: null,
  quick: false,
  search: "",
  error: "",
  busy: false,
};
const themes = [
  ["carbon", "Carbon", "Deep charcoal"],
  ["midnight", "Midnight", "Deep navy"],
  ["forest", "Forest", "Dark green"],
  ["plum", "Plum", "Warm purple"],
];
const accents = [
  ["mint", "Mint"],
  ["cyan", "Cyan"],
  ["violet", "Violet"],
  ["amber", "Amber"],
  ["coral", "Coral"],
];
function applyAppearance() {
  document.documentElement.dataset.theme = state.me?.theme || "carbon";
  document.documentElement.dataset.accent = state.me?.accent || "mint";
}
function appearancePicker() {
  const theme = state.me.theme || "carbon";
  const accent = state.me.accent || "mint";
  return (
    '<div class="appearance-picker"><div class="appearance-label">Theme</div><div class="theme-options">' +
    themes
      .map(
        ([id, label, description]) =>
          '<button type="button" class="theme-option" data-theme="' +
          id +
          '" aria-pressed="' +
          (theme === id) +
          '"><span class="theme-preview preview-' +
          id +
          '"></span><span><strong>' +
          label +
          "</strong><small>" +
          description +
          "</small></span>" +
          (theme === id ? svg("check") : "") +
          "</button>",
      )
      .join("") +
    '</div><div class="appearance-label">Accent</div><div class="accent-options">' +
    accents
      .map(
        ([id, label]) =>
          '<button type="button" class="accent-option" data-accent="' +
          id +
          '" aria-label="' +
          label +
          ' accent" aria-pressed="' +
          (accent === id) +
          '"><span class="accent-swatch swatch-' +
          id +
          '"></span><span>' +
          label +
          "</span>" +
          (accent === id ? svg("check") : "") +
          "</button>",
      )
      .join("") +
    "</div></div>"
  );
}

function has(page) {
  return Boolean(state.me && (state.me.admin || state.me.pages[page]));
}
function firstPage() {
  return navItems.find((n) => has(n[0]))?.[0] || "settings";
}
function activePage() {
  if (!["settings", "admin"].includes(state.page) && !has(state.page))
    state.page = firstPage();
  if (state.page === "admin" && !state.me.admin) state.page = firstPage();
  return state.page;
}
async function api(path, method = "GET", body) {
  const res = await fetch(path, {
    method,
    credentials: "same-origin",
    headers: body === undefined ? {} : { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data;
  try {
    data = await res.json();
  } catch {
    throw new Error("Invalid server response");
  }
  if (!res.ok) throw new Error(data.error || "Request failed: " + res.status);
  return data;
}
function toast(message, bad = false) {
  document.querySelector(".toast")?.remove();
  const el = document.createElement("div");
  el.className = "toast" + (bad ? " bad" : "");
  el.textContent = message;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3900);
}
function section(title, sub, action) {
  return (
    '<div class="between"><div><h3 class="panel-title">' +
    esc(title) +
    '</h3><div class="panel-caption">' +
    esc(sub) +
    "</div></div>" +
    (action || "") +
    "</div>"
  );
}
function linkPage(page, label) {
  return (
    '<button class="link" data-page="' +
    page +
    '">' +
    esc(label) +
    " " +
    svg("arrow") +
    "</button>"
  );
}
function pageHead(title, desc, extra = "") {
  return (
    '<div class="page-head"><div><div class="eyebrow">Haven / ' +
    esc(state.page) +
    "</div><h1>" +
    esc(title) +
    "</h1><p>" +
    esc(desc) +
    "</p></div>" +
    extra +
    "</div>"
  );
}
function navButton(n, mini = false) {
  const selected = n[0] === state.page;
  return (
    '<button class="' +
    (mini ? "" : "nav-item ") +
    (selected ? (mini ? "selected" : "active") : "") +
    '" data-page="' +
    n[0] +
    '" aria-current="' +
    (selected ? "page" : "false") +
    '">' +
    svg(n[2]) +
    "<span>" +
    esc(n[1]) +
    "</span></button>"
  );
}
function shell() {
  const menu = navItems.filter(
    (n) =>
      n[0] === "settings" || (n[0] === "admin" && state.me.admin) || has(n[0]),
  );
  const main = menu.filter((n) => !["settings", "admin"].includes(n[0]));
  applyAppearance();
  root.innerHTML =
    '<div class="shell"><aside class="sidebar"><button type="button" class="brand" data-page="overview" aria-label="Go to overview"><div class="mark">' +
    svg("home") +
    '</div><div><div class="brand-name">haven<span style="color:var(--mint)">.</span></div><div class="brand-small">private space</div></div></button><div class="nav-label">WORKSPACE</div>' +
    main.map((n) => navButton(n)).join("") +
    '<div class="nav-grow"></div><div class="nav-label">ACCOUNT</div>' +
    menu
      .filter((n) => ["settings", "admin"].includes(n[0]))
      .map((n) => navButton(n))
      .join("") +
    '<div class="nav-foot"><div class="nav-note"><span class="online-indicator"></span>Private network</div><div style="font-size:11px;margin-top:9px;color:#69798e">Connected to your home</div></div></aside>' +
    '<main class="main"><header class="topbar"><button type="button" class="breadcrumb" data-page="overview" aria-label="Go to overview">' +
    svg("home") +
    ' &nbsp; Haven <span style="opacity:.4">/</span> ' +
    esc(menu.find((n) => n[0] === state.page)?.[1] || "Workspace") +
    '</button><div class="top-actions"><button class="kbd-search" data-open="search">' +
    svg("search") +
    '<span>Quick search</span><span class="keycap">⌘ K</span></button><button class="icon-btn" data-open="quick" aria-label="Quick settings">' +
    svg("sliders") +
    '</button><button type="button" class="avatar" data-page="settings" aria-label="Account settings" title="' +
    esc(state.me.name) +
    '">' +
    esc(state.me.name.slice(0, 2).toUpperCase()) +
    '</button></div></header><div id="page-content">' +
    content() +
    "</div></main>" +
    '<nav class="bottomnav" aria-label="Primary navigation">' +
    main
      .slice(0, 4)
      .map((n) => navButton(n, true))
      .join("") +
    '<button data-open="quick">' +
    svg("sliders") +
    "<span>More</span></button></nav></div>" +
    (state.quick ? quickSheet() : "");
}
function render() {
  if (!state.me) {
    auth();
    return;
  }
  activePage();
  shell();
}
function auth() {
  applyAppearance();
  root.innerHTML =
    '<div class="auth"><div class="auth-card"><div class="auth-brand"><div class="mark">' +
    svg("home") +
    '</div><div><div class="brand-name">haven<span style="color:var(--mint)">.</span></div><div class="brand-small">your private space</div></div></div><div class="eyebrow">' +
    (state.ready ? "WELCOME BACK" : "FIRST RUN SETUP") +
    "</div><h1>" +
    (state.ready ? "Sign in to your home" : "Make this space yours") +
    "</h1><p>" +
    (state.ready
      ? "Use your Haven username and password. Other service connections are separate."
      : "Create the administrator account. The setup token is stored on the server and is never published to visitors.") +
    '</p><form id="auth-form">' +
    (!state.ready
      ? '<label class="field">Setup token<input class="input" name="token" type="password" required autocomplete="off" placeholder="Read from the server"></label>'
      : "") +
    '<label class="field">Username<input class="input" name="username" required minlength="3" autocomplete="username" autocapitalize="none" spellcheck="false" placeholder="Your username"></label><label class="field">Password<input class="input" name="password" required type="password" minlength="' +
    (state.ready ? "1" : "12") +
    '" autocomplete="' +
    (state.ready ? "current-password" : "new-password") +
    '" placeholder="Your password"></label><button class="btn primary" type="submit">' +
    (state.ready ? "Sign in" : "Create administrator") +
    " " +
    svg("arrow") +
    '</button><div id="auth-error" class="error" role="alert"></div></form><div class="auth-note">' +
    svg("lock") +
    " &nbsp;Private home infrastructure · Individual access controls</div></div></div>";
}
function quickSheet() {
  return (
    '<div class="overlay" data-dismiss="true"><section class="sheet" role="dialog" aria-label="Quick settings"><div class="between"><div><div class="eyebrow">SHORTCUTS</div><h2>Quick settings</h2></div><button class="icon-btn" data-close="true" aria-label="Close">' +
    svg("x") +
    '</button></div><p>Your most useful places and controls, always one click away.</p><div class="quick-sheet-list">' +
    quickTiles(true) +
    "</div>" +
    '<div class="section-bar"><h2>Appearance</h2></div>' +
    appearancePicker() +
    (has("home")
      ? '<div class="section-bar"><h2>Lights & controls</h2></div><div class="device-list">' +
        deviceSummary(4) +
        "</div>"
      : "") +
    '<div class="section-bar"><h2>Account</h2></div><div class="grid cols-2"><button class="btn" data-page="settings">' +
    svg("settings") +
    ' Settings</button><button class="btn danger" data-logout="true">' +
    svg("logout") +
    " Sign out</button></div></section></div>"
  );
}
function quickTiles(all = false) {
  const options = [
    ["home", "Lighting", "bulb"],
    ["media", "Downloads", "download"],
    ["infrastructure", "System health", "activity"],
    ["apps", "Applications", "apps"],
  ];
  if (all) options.push(["settings", "Connections", "lock"]);
  return options
    .filter((n) => n[0] === "settings" || has(n[0]))
    .map(
      (n) =>
        '<button class="quick-tile" data-page="' +
        n[0] +
        '">' +
        svg(n[2]) +
        "<span>" +
        esc(n[1]) +
        "</span></button>",
    )
    .join("");
}
function empty(text, icon = "spark") {
  return '<div class="empty">' + svg(icon) + esc(text) + "</div>";
}
function entitiesBy(domain) {
  return (state.entities || [])
    .filter((e) => e.entity_id.startsWith(domain + "."))
    .sort((a, b) => label(a).localeCompare(label(b)));
}
function label(e) {
  return String(e.attributes?.friendly_name || e.entity_id.replace(/_/g, " "));
}
function device(e) {
  const on = e.state === "on",
    domain = e.entity_id.split(".")[0],
    interactive = e.state !== "unavailable" && e.state !== "unknown";
  const brightness = Number(e.attributes?.brightness || 0),
    dim = domain === "light" && on && brightness > 0;
  return (
    '<div class="device" style="flex-wrap:wrap"><div class="device-icon ' +
    (on ? "on" : "") +
    '">' +
    svg(domain === "light" ? "bulb" : domain === "fan" ? "wind" : "power") +
    '</div><div class="device-text"><div class="device-name">' +
    esc(label(e)) +
    '</div><div class="device-state">' +
    esc(e.state === "on" ? "On" : e.state === "off" ? "Off" : e.state) +
    '</div></div><button aria-label="Toggle ' +
    esc(label(e)) +
    '" class="toggle ' +
    (on ? "on" : "") +
    '" data-entity="' +
    esc(e.entity_id) +
    '" ' +
    (interactive ? "" : "disabled") +
    "></button>" +
    (dim
      ? '<label class="device-slider"><span>Brightness</span><input aria-label="Brightness for ' +
        esc(label(e)) +
        '" type="range" min="1" max="100" value="' +
        Math.round((brightness / 255) * 100) +
        '" data-brightness="' +
        esc(e.entity_id) +
        '"></label>'
      : "") +
    "</div>"
  );
}
function deviceSummary(max = 4) {
  if (!has("home")) return empty("Smart home access is not enabled.", "lock");
  if (!state.me.credentials.homeassistant)
    return empty(
      "Connect Home Assistant in Settings to see your devices.",
      "bulb",
    );
  if (state.entities === null)
    return '<div class="loadingline"></div><div class="loadingline"></div>';
  if (state.haError) return empty(state.haError, "activity");
  const items = state.entities.slice(0, max);
  return items.length
    ? items.map(device).join("")
    : empty("No supported light, switch, or fan entities found.", "bulb");
}
function queues() {
  return ["sonarr", "radarr"].flatMap((service) =>
    (state.arr[service]?.records || []).map((r) => ({ ...r, service })),
  );
}
function queueSummary(max = 5) {
  if (!has("media")) return empty("Media access is not enabled.", "lock");
  if (!state.me.credentials.sonarr && !state.me.credentials.radarr)
    return empty(
      "Connect Sonarr or Radarr in Settings to view downloads.",
      "download",
    );
  const rows = queues().slice(0, max);
  return rows.length
    ? rows
        .map(
          (r) =>
            '<div class="table-row"><div style="min-width:0;flex:1"><div class="table-title">' +
            esc(r.title || r.service + " item") +
            '</div><div class="table-sub">' +
            esc(r.service === "sonarr" ? "Sonarr · TV" : "Radarr · Movie") +
            " · " +
            esc(r.status || "Queued") +
            (r.timeleft ? " · " + esc(r.timeleft) : "") +
            "</div>" +
            (r.size > 0
              ? '<div class="meter"><div class="meter-fill" style="width:' +
                Math.min(
                  100,
                  Math.max(0, (1 - r.sizeleft / r.size) * 100),
                ).toFixed(0) +
                '%"></div></div>'
              : "") +
            '</div><span class="chip">' +
            esc(r.status || "Queued") +
            "</span></div>",
        )
        .join("")
    : state.arrError
      ? empty(state.arrError, "activity")
      : empty("Nothing in the download queue right now.", "check");
}
function stat(title, value, sub, iconName) {
  return (
    '<div class="panel stat"><div class="stat-top">' +
    esc(title) +
    svg(iconName) +
    "</div><strong>" +
    esc(value) +
    "</strong><small>" +
    esc(sub) +
    "</small></div>"
  );
}
function overview() {
  const devices = state.entities || [],
    on = devices.filter((e) => e.state === "on").length,
    queue = queues().length,
    health = (state.health || []).filter((h) => h.online).length;
  const first = state.me.name.charAt(0).toUpperCase() + state.me.name.slice(1);
  return (
    pageHead(
      "Home, at a glance",
      "The essentials across your home and infrastructure.",
    ) +
    '<section class="panel hero"><div><div class="eyebrow">YOUR SPACE, IN SYNC</div><h2>Welcome home, ' +
    esc(first) +
    '.</h2><p>A quieter way to keep everything connected. Your services, your home, and the things that matter, all together.</p><div style="margin-top:20px"><span class="chip good"><span class="dot"></span>Private workspace</span></div></div><div class="hero-art">' +
    svg("home") +
    "</div></section>" +
    '<div class="stats">' +
    stat(
      "Smart devices",
      state.entities ? state.entities.length : "—",
      on + " currently on",
      "bulb",
    ) +
    stat("Media queue", queue, "active downloads shown", "download") +
    stat(
      "Service health",
      state.health ? health + "/" + state.health.length : "—",
      "services reachable",
      "server",
    ) +
    stat(
      "Your access",
      Object.values(state.me.pages).filter(Boolean).length +
        (state.me.admin ? "+" : ""),
      "enabled pages",
      "shield",
    ) +
    "</div>" +
    '<div class="grid cols-2"><section class="panel">' +
    section(
      "Quick access",
      "Jump straight to what matters",
      linkPage("settings", "Customise"),
    ) +
    '<div class="quick-grid">' +
    quickTiles() +
    '</div></section><section class="panel">' +
    section(
      "Your smart home",
      "Real-time controls from Home Assistant",
      linkPage("home", "All devices"),
    ) +
    '<div class="device-list">' +
    deviceSummary(3) +
    '</div></section><section class="panel">' +
    section(
      "Media activity",
      "Sonarr and Radarr download queues",
      linkPage("media", "See queue"),
    ) +
    '<div class="queue-list">' +
    queueSummary(4) +
    '</div></section><section class="panel">' +
    section(
      "Infrastructure pulse",
      "Current connectivity of key services",
      linkPage("infrastructure", "System health"),
    ) +
    (state.health
      ? '<div class="service-list">' +
        state.health
          .slice(0, 5)
          .map(
            (h) =>
              '<div class="between table-row"><div class="row"><span class="dot" style="color:' +
              (h.online ? "var(--mint)" : "var(--red)") +
              '"></span><span class="table-title">' +
              esc(h.name) +
              '</span></div><span class="chip ' +
              (h.online ? "good" : "bad") +
              '">' +
              (h.online ? "Online" : "Offline") +
              "</span></div>",
          )
          .join("") +
        "</div>"
      : empty("Open Infrastructure for live status.", "activity")) +
    "</section></div>"
  );
}
function home() {
  const grouped = [
    ["Lights", "light", "bulb"],
    ["Switches", "switch", "power"],
    ["Fans", "fan", "wind"],
    ["Other controls", "input_boolean", "sliders"],
  ];
  let markup = "";
  for (const g of grouped) {
    const items = entitiesBy(g[1]);
    if (!items.length) continue;
    markup +=
      '<section class="panel"><div class="between">' +
      section(g[0], items.length + " connected entities") +
      '<span class="chip">' +
      svg(g[2]) +
      items.filter((e) => e.state === "on").length +
      ' active</span></div><div class="device-list">' +
      items.map(device).join("") +
      "</div></section>";
  }
  return (
    pageHead(
      "Smart Home",
      "One beautiful place to control your home.",
      linkPage("settings", "Manage connection"),
    ) +
    (!state.me.credentials.homeassistant
      ? '<section class="panel">' +
        empty(
          "Connect your personal Home Assistant access token under Settings.",
          "lock",
        ) +
        "</section>"
      : state.haError
        ? '<section class="panel">' +
          empty(state.haError, "activity") +
          "</section>"
        : state.entities === null
          ? '<section class="panel"><div class="loadingline"></div></section>'
          : markup
            ? '<div class="grid cols-2">' + markup + "</div>"
            : '<section class="panel">' +
              empty("No light, fan, or switch entities available.", "bulb") +
              "</section>")
  );
}
function media() {
  const cards = ["sonarr", "radarr"]
    .map((name) => {
      const connected = state.me.credentials[name],
        data = state.arr[name];
      return (
        '<section class="panel">' +
        section(
          name === "sonarr" ? "Television · Sonarr" : "Movies · Radarr",
          connected
            ? data
              ? (data.totalRecords || 0) + " items queued"
              : "Loading queue…"
            : "Not connected",
          '<span class="chip ' +
            (connected ? "good" : "warn") +
            '">' +
            (connected ? "Connected" : "Needs token") +
            "</span>",
        ) +
        '<div class="queue-list">' +
        (!connected
          ? empty("Connect your " + name + " API key in Settings.", "lock")
          : data
            ? (data.records || []).length
              ? data.records
                  .map(
                    (r) =>
                      '<div class="table-row"><div style="min-width:0"><div class="table-title">' +
                      esc(r.title || "Media item") +
                      '</div><div class="table-sub">' +
                      esc(r.status || "Queued") +
                      (r.timeleft ? " · " + esc(r.timeleft) : "") +
                      "</div>" +
                      (r.size > 0
                        ? '<div class="meter"><div class="meter-fill" style="width:' +
                          Math.min(
                            100,
                            Math.max(0, (1 - r.sizeleft / r.size) * 100),
                          ).toFixed(0) +
                          '%"></div></div>'
                        : "") +
                      "</div></div>",
                  )
                  .join("")
              : empty("Your queue is clear.", "check")
            : state.arrError
              ? empty(state.arrError, "activity")
              : '<div class="loadingline"></div>') +
        "</div></section>"
      );
    })
    .join("");
  return (
    pageHead(
      "Media centre",
      "Keep an eye on what you are watching and what is downloading.",
      linkPage("settings", "Manage connections"),
    ) +
    '<div class="grid cols-2">' +
    cards +
    '</div><div class="section-bar"><h2>Media applications</h2></div>' +
    serviceCards(state.catalog.filter((a) => a.page === "media"))
  );
}
function infrastructure() {
  const items = state.health || [];
  const list = items
    .map(
      (e) =>
        '<div class="table-row"><div class="row"><span class="dot" style="color:' +
        (e.online ? "var(--mint)" : "var(--red)") +
        '"></span><div><div class="table-title">' +
        esc(e.name) +
        '</div><div class="table-sub">' +
        (e.online
          ? "Reachable · " + e.delayMs + " ms"
          : "Not reachable from the server") +
        '</div></div></div><span class="chip ' +
        (e.online ? "good" : "bad") +
        '">' +
        (e.online ? "Online" : "Unavailable") +
        "</span></div>",
    )
    .join("");
  return (
    pageHead(
      "Infrastructure",
      "Visibility across the services that keep everything running.",
      '<button class="btn" data-refresh="true">' +
        svg("activity") +
        " Refresh</button>",
    ) +
    '<div class="grid cols-2"><section class="panel">' +
    section("Service availability", "Private checks run on your server") +
    (state.health
      ? '<div class="service-list">' + list + "</div>"
      : '<div class="loadingline"></div>') +
    '</section><section class="panel">' +
    section("Operations", "Open specialist admin interfaces when needed") +
    '<div class="service-list">' +
    state.catalog
      .filter((a) => a.page === "infrastructure")
      .map(serviceRow)
      .join("") +
    '</div><div class="bottom-spacer"></div><div class="chip">' +
    svg("shield") +
    " Internal network only</div></section></div>"
  );
}
function logoFor(a) {
  return (
    {
      ha: "home",
      jellyfin: "play",
      sonarr: "play",
      radarr: "play",
      prowlarr: "search",
      bazarr: "doc",
      transmission: "download",
      immich: "image",
      paperless: "doc",
      n8n: "sliders",
      openwebui: "spark",
      openclaw: "spark",
      gitea: "server",
      adguard: "shield",
      technitium: "server",
    }[a.id] || "apps"
  );
}
function serviceRow(a) {
  return (
    '<a class="service-card" href="' +
    esc(a.url) +
    '" target="_blank" rel="noopener noreferrer"><div class="service-icon">' +
    svg(logoFor(a)) +
    '</div><div style="min-width:0"><div class="service-name">' +
    esc(a.name) +
    '</div><div class="service-sub">' +
    esc(a.category) +
    '</div></div><div class="arrow">' +
    svg("external") +
    "</div></a>"
  );
}
function serviceCards(items) {
  return (
    '<div class="grid cols-3">' +
    (items.length
      ? items.map(serviceRow).join("")
      : empty("No services available for this section.")) +
    "</div>"
  );
}
function applications() {
  const matching = state.catalog.filter(
    (a) =>
      !state.search ||
      [a.name, a.category].some((x) =>
        x.toLowerCase().includes(state.search.toLowerCase()),
      ),
  );
  return (
    pageHead(
      "Applications",
      "Your home services, all in one place.",
      '<input class="input search-input" id="app-search" placeholder="Filter services…" value="' +
        esc(state.search) +
        '" aria-label="Filter services">',
    ) + serviceCards(matching)
  );
}
function settings() {
  const relevant = Object.keys(state.me.credentials || {});
  const descriptions = {
    homeassistant: "Smart home devices, states, and actions",
    sonarr: "TV downloads and activity",
    radarr: "Movie downloads and activity",
  };
  const names = {
    homeassistant: "Home Assistant",
    sonarr: "Sonarr",
    radarr: "Radarr",
  };
  return (
    pageHead(
      "Settings",
      "Keep your connections personal and your credentials private.",
    ) +
    '<section class="panel" style="margin-bottom:16px">' +
    section("Your account", "Each person signs in independently") +
    '<div class="row" style="margin-top:20px"><div class="avatar">' +
    esc(state.me.name.slice(0, 2).toUpperCase()) +
    '</div><div><div class="table-title">' +
    esc(state.me.name) +
    '</div><div class="table-sub">' +
    (state.me.admin ? "Administrator" : "Member") +
    '</div></div><div style="flex:1"></div><button class="btn danger" data-logout="true">' +
    svg("logout") +
    " Sign out</button></div></section>" +
    '<section class="panel" style="margin-bottom:16px">' +
    section("Appearance", "Choose a theme and accent for your account") +
    appearancePicker() +
    "</section>" +
    '<section class="panel" style="margin-bottom:16px">' +
    section("Password", "Change your own sign-in password") +
    '<form id="change-password" style="margin-top:16px"><label class="field">Current password<input class="input" name="current" type="password" required autocomplete="current-password"></label><label class="field">New password<input class="input" name="password" type="password" minlength="12" required autocomplete="new-password"></label><button class="btn" style="margin-top:14px" type="submit">' +
    svg("lock") +
    " Change password</button></form></section>" +
    '<div class="section-bar"><h2>Personal service connections</h2></div><div class="creds-grid">' +
    relevant
      .map(
        (id) =>
          '<section class="panel cred-card">' +
          section(
            names[id] || id,
            descriptions[id] || "Personal service connection",
            '<span class="pill">' +
              (state.me.credentials[id] ? "Connected" : "Not connected") +
              "</span>",
          ) +
          '<form class="cred-form" data-service="' +
          esc(id) +
          '"><label class="field">Personal access token / API key<input class="input" type="password" name="token" required autocomplete="off" placeholder="' +
          (state.me.credentials[id]
            ? "Replace saved token…"
            : "Paste your token…") +
          '"></label><div class="between" style="margin-top:13px"><button class="btn primary" type="submit">' +
          svg("check") +
          " Save securely</button>" +
          (state.me.credentials[id]
            ? '<button class="btn danger" type="button" data-disconnect="' +
              esc(id) +
              '">Disconnect</button>'
            : "") +
          "</div></form></section>",
      )
      .join("") +
    '</div><p class="muted small" style="margin-top:17px">Tokens stay on this server and are never sent back to the browser. Each account has its own saved connections. Service-level privileges are still determined by the upstream service.</p>'
  );
}
function permsForm(name, pages, unique) {
  return (
    '<div class="permission-grid">' +
    navItems
      .filter((n) =>
        ["overview", "home", "media", "infrastructure", "apps"].includes(n[0]),
      )
      .map(
        (n) =>
          '<label class="permission"><input type="checkbox" data-perm="' +
          esc(n[0]) +
          '" data-user="' +
          esc(unique) +
          '" ' +
          (pages[n[0]] ? "checked" : "") +
          ">" +
          svg(n[2]) +
          " " +
          esc(n[1]) +
          "</label>",
      )
      .join("") +
    "</div>"
  );
}
function admin() {
  const us = (state.users || [])
    .slice()
    .sort((a, b) => a.name.localeCompare(b.name));
  return (
    pageHead(
      "Users & access",
      "Give each person exactly the pages they need.",
    ) +
    '<div class="grid cols-2"><section class="panel">' +
    section(
      "Create a member",
      "New accounts start without service connections",
    ) +
    '<form id="create-user" style="margin-top:20px"><label class="field">Username<input class="input" name="name" required minlength="3" placeholder="e.g. alex"></label><label class="field">Temporary password<input class="input" name="password" type="password" autocomplete="new-password" minlength="12" required placeholder="At least 12 characters"></label><div style="margin-top:18px;font-size:12px;font-weight:700">Allowed pages</div>' +
    permsForm("", {}, "new") +
    '<button class="btn primary" type="submit">' +
    svg("users") +
    " Create member</button></form></section>" +
    '<section class="panel">' +
    section("Existing accounts", us.length + " member(s)") +
    (state.users === null
      ? '<div class="loadingline"></div>'
      : us
          .map(
            (u) =>
              '<div class="user-row"><div class="between"><div><div class="table-title">' +
              esc(u.name) +
              " " +
              (u.admin ? '<span class="chip good">Admin</span>' : "") +
              '</div><div class="table-sub">' +
              (u.enabled ? "Account enabled" : "Account disabled") +
              "</div></div>" +
              (u.admin
                ? ""
                : '<button class="btn danger" data-remove-user="' +
                  esc(u.name) +
                  '">Remove</button>') +
              "</div>" +
              (u.admin
                ? ""
                : permsForm(u.name, u.pages || {}, u.name) +
                  '<div class="row wrap"><button class="btn" data-save-user="' +
                  esc(u.name) +
                  '">' +
                  svg("check") +
                  ' Save access</button><button class="btn" data-toggle-user="' +
                  esc(u.name) +
                  '" data-enabled="' +
                  (u.enabled ? "false" : "true") +
                  '">' +
                  (u.enabled ? "Disable account" : "Enable account") +
                  '</button><button class="btn ghost" data-password-user="' +
                  esc(u.name) +
                  '">Reset password</button></div>') +
              "</div>",
          )
          .join("")) +
    "</section></div>"
  );
}
function searchSheet() {
  return (
    '<div class="overlay" data-dismiss="true"><section class="sheet" role="dialog" aria-label="Quick navigation"><div class="between"><h2>Go somewhere</h2><button class="icon-btn" data-close="true">' +
    svg("x") +
    '</button></div><p>Jump directly to a page or application.</p><input id="command-input" class="input" autofocus placeholder="Search pages and apps…" style="margin:15px 0"><div id="command-results"></div></section></div>'
  );
}
function content() {
  return (
    {
      overview,
      home,
      media,
      infrastructure,
      apps: applications,
      settings,
      admin,
    }[state.page]?.() || overview()
  );
}
function move(page) {
  state.quick = false;
  if (page !== "settings" && page !== "admin" && !has(page)) return;
  if (page === "admin" && !state.me.admin) return;
  state.page = page;
  state.search = "";
  location.hash = page;
  render();
  refreshPage(page);
}
async function refreshPage(page) {
  const jobs = [];
  if (
    (page === "home" || page === "overview") &&
    has("home") &&
    state.me.credentials.homeassistant
  )
    jobs.push(
      api("/api/ha/entities")
        .then((v) => {
          state.entities = v;
          state.haError = "";
        })
        .catch((e) => {
          state.haError = e.message;
          state.entities = [];
        }),
    );
  if ((page === "media" || page === "overview") && has("media"))
    for (const service of ["sonarr", "radarr"])
      if (state.me.credentials[service])
        jobs.push(
          api("/api/arr/" + service)
            .then((v) => {
              state.arr[service] = v;
              state.arrError = "";
            })
            .catch((e) => {
              state.arrError = e.message;
              state.arr[service] = { records: [] };
            }),
        );
  if (
    (page === "infrastructure" || page === "overview") &&
    has("infrastructure")
  )
    jobs.push(
      api("/api/health").then((v) => {
        state.health = v;
      }),
    );
  if (page === "admin" && state.me.admin)
    jobs.push(
      api("/api/users").then((v) => {
        state.users = v;
      }),
    );
  await Promise.allSettled(jobs);
  if (state.page === page) render();
}
async function init() {
  try {
    const result = await api("/api/session");
    state.me = result;
    state.page = location.hash.slice(1) || "overview";
    try {
      state.catalog = await api("/api/catalog");
    } catch {
      state.catalog = [];
    }
    render();
    refreshPage(state.page);
  } catch {
    try {
      const status = await api("/api/setup/status");
      state.ready = status.ready;
    } catch {
      state.ready = true;
    }
    auth();
  }
}
document.addEventListener("click", async (e) => {
  const target = e.target.closest("button,[data-dismiss],a[data-page]");
  if (!target) return;
  if (target.dataset.theme || target.dataset.accent) {
    const previous = { theme: state.me.theme, accent: state.me.accent };
    state.me.theme = target.dataset.theme || state.me.theme || "carbon";
    state.me.accent = target.dataset.accent || state.me.accent || "mint";
    applyAppearance();
    render();
    try {
      await api("/api/profile/appearance", "PUT", {
        theme: state.me.theme,
        accent: state.me.accent,
      });
    } catch (err) {
      Object.assign(state.me, previous);
      render();
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.page) {
    e.preventDefault();
    move(target.dataset.page);
    return;
  }
  if (target.dataset.open === "quick") {
    state.quick = true;
    render();
    return;
  }
  if (target.dataset.open === "search") {
    state.quick = false;
    render();
    root.insertAdjacentHTML("beforeend", searchSheet());
    document.getElementById("command-input")?.focus();
    renderResults("");
    return;
  }
  if (target.dataset.close || (target.dataset.dismiss && e.target === target)) {
    state.quick = false;
    render();
    return;
  }
  if (target.dataset.entity) {
    const entity = target.dataset.entity;
    target.disabled = true;
    try {
      await api("/api/ha/action", "POST", { entity, action: "toggle" });
      const v = state.entities.find((d) => d.entity_id === entity);
      if (v) v.state = v.state === "on" ? "off" : "on";
      render();
      setTimeout(() => refreshPage(state.page), 750);
    } catch (err) {
      toast(err.message, true);
      target.disabled = false;
    }
    return;
  }
  if (target.dataset.refresh) {
    refreshPage(state.page);
    return;
  }
  if (target.dataset.logout) {
    try {
      await api("/api/logout", "POST");
      state.me = null;
      state.quick = false;
      auth();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.disconnect) {
    if (!confirm("Disconnect your " + target.dataset.disconnect + " account?"))
      return;
    try {
      await api("/api/credentials/" + target.dataset.disconnect, "PUT", {
        token: "",
      });
      state.me.credentials[target.dataset.disconnect] = false;
      toast("Connection removed");
      render();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.removeUser) {
    if (
      !confirm(
        "Remove user " +
          target.dataset.removeUser +
          " and their saved connections?",
      )
    )
      return;
    try {
      await api(
        "/api/users/" + encodeURIComponent(target.dataset.removeUser),
        "DELETE",
      );
      toast("User removed");
      state.users = await api("/api/users");
      render();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.saveUser) {
    const name = target.dataset.saveUser,
      perms = {};
    document
      .querySelectorAll('input[data-user="' + CSS.escape(name) + '"]')
      .forEach((x) => {
        perms[x.dataset.perm] = x.checked;
      });
    try {
      await api("/api/users/" + encodeURIComponent(name), "PATCH", {
        pages: perms,
      });
      toast("Access updated");
      state.users = await api("/api/users");
      render();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.toggleUser) {
    try {
      await api(
        "/api/users/" + encodeURIComponent(target.dataset.toggleUser),
        "PATCH",
        { enabled: target.dataset.enabled === "true" },
      );
      toast("Account updated");
      state.users = await api("/api/users");
      render();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.passwordUser) {
    const password = prompt(
      "New password (12 characters minimum) for " + target.dataset.passwordUser,
    );
    if (password === null) return;
    try {
      await api(
        "/api/users/" + encodeURIComponent(target.dataset.passwordUser),
        "PATCH",
        { password },
      );
      toast("Password updated; old sessions revoked");
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
});
document.addEventListener("submit", async (e) => {
  const f = e.target;
  if (f.id === "auth-form") {
    e.preventDefault();
    const b = Object.fromEntries(new FormData(f));
    const error = f.querySelector("#auth-error");
    error.textContent = "";
    const btn = f.querySelector("button");
    btn.disabled = true;
    try {
      state.me = await api(
        state.ready ? "/api/login" : "/api/setup",
        "POST",
        b,
      );
      state.ready = true;
      try {
        state.catalog = await api("/api/catalog");
      } catch {
        state.catalog = [];
      }
      move("overview");
    } catch (err) {
      error.textContent =
        err.message === "Invalid credentials"
          ? "Invalid credentials. Use your Haven password and check your username."
          : err.message;
    } finally {
      btn.disabled = false;
    }
    return;
  }
  if (f.classList.contains("cred-form")) {
    e.preventDefault();
    const service = f.dataset.service,
      token = new FormData(f).get("token");
    try {
      await api("/api/credentials/" + service, "PUT", { token });
      state.me.credentials[service] = true;
      toast("Connection saved");
      state.entities = null;
      state.arr = {};
      render();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (f.id === "change-password") {
    e.preventDefault();
    const b = Object.fromEntries(new FormData(f));
    try {
      await api("/api/profile/password", "POST", b);
      toast("Password changed. Sign in again.");
      state.me = null;
      auth();
    } catch (err) {
      toast(err.message, true);
    }
    return;
  }
  if (f.id === "create-user") {
    e.preventDefault();
    const inputs = Object.fromEntries(new FormData(f)),
      pages = {};
    f.querySelectorAll("input[data-perm]").forEach((x) => {
      pages[x.dataset.perm] = x.checked;
    });
    try {
      await api("/api/users", "POST", {
        name: inputs.name,
        password: inputs.password,
        pages,
      });
      toast("Member created");
      state.users = await api("/api/users");
      render();
    } catch (err) {
      toast(err.message, true);
    }
  }
});
function renderResults(q) {
  const results = navItems
    .filter(
      (n) =>
        (n[0] === "admin" && state.me.admin) ||
        n[0] === "settings" ||
        has(n[0]),
    )
    .filter((n) => n[1].toLowerCase().includes(q.toLowerCase()));
  const apps = state.catalog.filter((a) =>
    a.name.toLowerCase().includes(q.toLowerCase()),
  );
  const node = document.getElementById("command-results");
  if (!node) return;
  node.innerHTML =
    '<div class="nav-label">PAGES</div>' +
    results
      .map(
        (n) =>
          '<button class="nav-item" data-page="' +
          n[0] +
          '">' +
          svg(n[2]) +
          "<span>" +
          esc(n[1]) +
          "</span></button>",
      )
      .join("") +
    '<div class="nav-label">APPLICATIONS</div>' +
    apps
      .slice(0, 12)
      .map((a) => serviceRow(a))
      .join("") +
    (!results.length && !apps.length
      ? empty("Nothing matched your search.", "search")
      : "");
}
document.addEventListener("change", async (e) => {
  if (!e.target.dataset.brightness) return;
  const entity = e.target.dataset.brightness;
  try {
    await api("/api/ha/action", "POST", {
      entity,
      action: "brightness",
      brightness: Number(e.target.value),
    });
    toast("Brightness updated");
  } catch (err) {
    toast(err.message, true);
  }
});
document.addEventListener("input", (e) => {
  if (e.target.id === "command-input") renderResults(e.target.value);
  if (e.target.id === "app-search") {
    state.search = e.target.value;
    const container = document.querySelector("#page-content .grid");
    if (container)
      container.innerHTML = state.catalog
        .filter(
          (a) =>
            !state.search ||
            [a.name, a.category].some((s) =>
              s.toLowerCase().includes(state.search.toLowerCase()),
            ),
        )
        .map(serviceRow)
        .join("");
  }
});
document.addEventListener("keydown", (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
    e.preventDefault();
    if (state.me) {
      state.quick = false;
      render();
      root.insertAdjacentHTML("beforeend", searchSheet());
      document.getElementById("command-input")?.focus();
      renderResults("");
    }
  }
  if (e.key === "Escape" && state.me) {
    if (document.querySelector(".overlay")) {
      state.quick = false;
      render();
    }
  }
});
window.addEventListener("hashchange", () => {
  if (state.me && location.hash.slice(1) !== state.page)
    move(location.hash.slice(1));
});
document.addEventListener("visibilitychange", () => {
  if (!document.hidden && state.me) refreshPage(state.page);
});
setInterval(() => {
  if (
    !document.hidden &&
    state.me &&
    ["overview", "home", "media", "infrastructure"].includes(state.page)
  )
    refreshPage(state.page);
}, 20000);
init();
