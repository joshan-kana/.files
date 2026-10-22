const root = document.getElementById("app");
const navItems = [
  ["overview", "Overview", "grid"],
  ["home", "Smart Home", "home"],
  ["media", "Media", "play"],
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
  areas: {},
  deviceRegistry: {},
  deviceRegistryLoaded: false,
  showReadings: false,
  mediaFilter: "All",
  room: "All",
  homeSearch: "",
  device: null,
  roomPicker: false,
  appCategory: "All",
  arr: {},
  users: null,
  quick: false,
  search: "",
  areasLoaded: false,
  error: "",
  busy: false,
  help: false,
  keyboardMode: false,
  keyboardTarget: "",
  fanFeedback: {},
  fanSequence: 0,
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
  document.documentElement.dataset.hand = state.me?.hand || "right";
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
    "</span>" +
    (!mini && ["overview", "home", "media", "apps"].includes(n[0])
      ? '<kbd class="nav-shortcut">' +
        (["overview", "home", "media", "apps"].indexOf(n[0]) + 1) +
        "</kbd>"
      : "") +
    "</button>"
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
    '<span>Quick search</span><span class="keycap">/</span></button><button class="icon-btn desktop-help" data-open="help" aria-label="Keyboard shortcuts" title="Keyboard shortcuts (?)">?</button><button class="icon-btn" data-open="quick" aria-label="Quick settings">' +
    svg("sliders") +
    '</button><button type="button" class="avatar" data-page="settings" aria-label="Account settings" title="' +
    esc(state.me.name) +
    '">' +
    esc(state.me.name.slice(0, 2).toUpperCase()) +
    '</button></div></header><div class="keyboard-hintbar"><span><kbd>1</kbd>–<kbd>4</kbd> Pages</span><span><kbd>h</kbd><kbd>j</kbd><kbd>k</kbd><kbd>l</kbd> Navigate</span><span><kbd>↵</kbd> Open</span><span><kbd>t</kbd> Toggle</span><span><kbd>/</kbd> Search</span><button data-open="help"><kbd>?</kbd> All shortcuts</button></div><div id="page-content">' +
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
    (state.quick ? quickSheet() : "") +
    (state.device ? deviceSheet() : "") +
    (state.roomPicker ? roomsSheet() : "") +
    (state.help ? helpSheet() : "");
}
function render() {
  if (!state.me) {
    auth();
    return;
  }
  activePage();
  shell();
  if (
    state.keyboardMode &&
    state.keyboardTarget &&
    !document.querySelector(".overlay")
  ) {
    const focus = [
      ...document.querySelectorAll(".home-tile .tile-open, .app-card"),
    ].find(
      (item) => (item.dataset.device || item.href) === state.keyboardTarget,
    );
    focus?.focus({ preventScroll: true });
  }
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
function helpSheet() {
  const shortcuts = [
    ["1 / 2 / 3 / 4", "Overview / Home / Media / Apps"],
    ["h / j / k / l", "Move between tiles"],
    ["Enter", "Open selected device or application"],
    ["t", "Toggle selected device’s primary control"],
    ["/", "Search devices, apps or pages"],
    ["⌘ K / Ctrl K", "Open command palette"],
    ["r", "Refresh current page"],
    ["Esc", "Close a panel or clear focus"],
    ["?", "Show or hide this guide"],
  ];
  return `<div class="overlay" data-dismiss="true"><section class="sheet shortcut-sheet" role="dialog" aria-label="Keyboard shortcuts"><div class="between"><div><div class="eyebrow">DESKTOP WORKFLOW</div><h2>Keyboard shortcuts</h2></div><button class="icon-btn" data-close="true" aria-label="Close">${svg("x")}</button></div><p>Keep your hands on the keyboard. Shortcuts are disabled while typing in a field.</p><div class="shortcut-list">${shortcuts.map(([keys, description]) => `<div class="shortcut-row"><kbd>${esc(keys)}</kbd><span>${esc(description)}</span></div>`).join("")}</div></section></div>`;
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
function overview() {
  const devices = state.entities || [];
  const active = homeDevices().filter((d) =>
    d.controls.some((e) => e.state === "on"),
  ).length;
  return (
    '<div class="welcome"><div class="eyebrow">YOUR PRIVATE SPACE</div><h1>Good to have you home.</h1><p>Everything you use, without the noise.</p></div>' +
    '<div class="overview-metrics">' +
    '<button class="metric" data-page="home"><span>' +
    svg("bulb") +
    " Smart Home</span><strong>" +
    (state.entities ? active + " active" : "Devices") +
    "</strong><small>Control your space " +
    svg("arrow") +
    "</small></button>" +
    '<button class="metric" data-page="media"><span>' +
    svg("play") +
    " Downloads</span><strong>" +
    queues().length +
    " in queue</strong><small>Sonarr & Radarr " +
    svg("arrow") +
    "</small></button>" +
    '<button class="metric" data-page="apps"><span>' +
    svg("apps") +
    " Applications</span><strong>" +
    state.catalog.length +
    " available</strong><small>Open any service " +
    svg("arrow") +
    "</small></button></div>" +
    '<div class="section-bar"><h2>Your services</h2>' +
    linkPage("apps", "See all") +
    "</div>" +
    serviceCards(state.catalog.slice(0, 6)) +
    (has("home")
      ? '<div class="section-bar"><h2>Home controls</h2>' +
        linkPage("home", "Open Smart Home") +
        '</div><div class="home-grid preview-grid">' +
        homeDevices()
          .filter((d) => d.controls.length)
          .slice(0, 4)
          .map(homeTile)
          .join("") +
        "</div>"
      : "")
  );
}
function controllable(e) {
  return [
    "light",
    "switch",
    "fan",
    "input_boolean",
    "cover",
    "climate",
    "scene",
  ].includes(e.entity_id.split(".")[0]);
}
function homeDevices() {
  const groups = new Map();
  for (const e of state.entities || []) {
    const reg = state.deviceRegistry[e.entity_id];
    // Orphaned, unavailable template buttons are not physical devices.
    // Their real fan (or other device) remains accessible via its own registry entry.
    if (!reg && domainOf(e) === "button" && e.state === "unavailable") continue;
    const id = reg?.id || "entity:" + e.entity_id;
    if (!groups.has(id))
      groups.set(id, {
        id,
        name: reg?.name || label(e),
        model: reg?.model || "",
        area: reg?.room || state.areas[e.entity_id] || "",
        entities: [],
      });
    groups.get(id).entities.push(e);
  }
  return [...groups.values()]
    .map((d) => {
      d.entities.sort((a, b) => a.entity_id.localeCompare(b.entity_id));
      d.controls = d.entities.filter((e) => isActionable(e));
      d.readings = d.entities.filter((e) =>
        ["sensor", "binary_sensor"].includes(domainOf(e)),
      );
      d.primary =
        [...d.controls].sort((a, b) => priority(a) - priority(b))[0] ||
        d.readings[0] ||
        d.entities[0];
      d.key = d.primary.entity_id;
      d.favourite = d.entities.some((e) =>
        (state.me.favorites || []).includes(e.entity_id),
      );
      d.room =
        d.entities.map((e) => state.me.rooms?.[e.entity_id]).find(Boolean) ||
        d.area ||
        "Unassigned";
      d.kind = deviceKind(d);
      return d;
    })
    .filter((d) => d.controls.length || d.readings.length);
}
function domainOf(e) {
  return e.entity_id.split(".")[0];
}
function isActionable(e) {
  return [
    "light",
    "switch",
    "fan",
    "input_boolean",
    "cover",
    "climate",
    "scene",
    "button",
    "number",
    "select",
    "media_player",
  ].includes(domainOf(e));
}
function priority(e) {
  return (
    {
      light: 0,
      fan: 1,
      climate: 2,
      cover: 3,
      switch: 4,
      media_player: 5,
      input_boolean: 6,
      scene: 7,
      select: 8,
      number: 9,
      button: 10,
    }[domainOf(e)] ?? 99
  );
}
function deviceKind(d) {
  const types = new Set(d.controls.map(domainOf));
  const count = (domain) =>
    d.controls.filter((e) => domainOf(e) === domain).length;
  // Light strips may expose a dozen auxiliary entities, but the light remains
  // the primary useful control. A printer with multiple fans is an appliance.
  if (types.has("light") && count("fan") < 2 && count("button") < 3)
    return "light";
  if (types.has("fan") && count("fan") === 1 && count("button") < 3)
    return "climate";
  if (d.controls.length >= 8 && types.size >= 3) return "mixed";
  if (types.has("light")) return "light";
  if (types.has("fan") || types.has("climate")) return "climate";
  if (types.has("cover")) return "cover";
  if (types.has("media_player")) return "media";
  if (types.has("switch") || types.has("input_boolean")) return "power";
  if (types.size) return "other";
  return "sensor";
}
function homeRoom(d) {
  return d.room;
}
function homeRooms() {
  return [
    ...new Set(
      homeDevices()
        .map((d) => d.room)
        .filter((r) => r !== "Unassigned"),
    ),
  ].sort((a, b) => a.localeCompare(b));
}
function homeItems() {
  let items = homeDevices();
  if (state.room === "Favorites") items = items.filter((d) => d.favourite);
  else if (state.room === "Sensors")
    items = items.filter((d) => !d.controls.length);
  else if (state.room === "All")
    items = items.filter((d) => d.controls.length || d.area !== "");
  else items = items.filter((d) => d.room === state.room);
  if (state.homeSearch.trim()) {
    const q = state.homeSearch.trim().toLowerCase();
    items = items.filter((d) =>
      [d.name, d.room, d.model, ...d.entities.map(label)].some((v) =>
        v.toLowerCase().includes(q),
      ),
    );
  }
  return items.sort(
    (a, b) =>
      Number(b.favourite) - Number(a.favourite) || a.name.localeCompare(b.name),
  );
}
function domainIcon(domain) {
  return (
    {
      light: "bulb",
      switch: "power",
      fan: "wind",
      climate: "sun",
      cover: "sliders",
      scene: "spark",
      sensor: "activity",
      binary_sensor: "shield",
      button: "power",
      select: "sliders",
      number: "sliders",
      media_player: "play",
    }[domain] || "apps"
  );
}
function deviceState(e) {
  if (e.state === "unavailable" || e.state === "unknown") return "Unavailable";
  const domain = domainOf(e);
  if (domain === "climate")
    return e.attributes?.current_temperature != null
      ? `${e.attributes.current_temperature}° · ${e.state}`
      : e.state;
  if (domain === "sensor")
    return `${e.state}${e.attributes?.unit_of_measurement || ""}`;
  if (domain === "scene") return "Run scene";
  if (e.state === "on")
    return domain === "light" && e.attributes?.brightness
      ? `${Math.round((e.attributes.brightness / 255) * 100)}% brightness`
      : "On";
  if (e.state === "off") return "Off";
  return e.state;
}
function deviceSummaryLine(d) {
  const primary = d.primary;
  if (d.controls.length === 1 && !d.readings.length)
    return deviceState(primary);
  const parts = [];
  if (d.controls.length) parts.push(`${d.controls.length} controls`);
  if (d.readings.length) parts.push(`${d.readings.length} readings`);
  return parts.join(" · ") || deviceState(primary);
}
function cardPower(e) {
  const active = e.state === "on";
  const unavailable = ["unknown", "unavailable"].includes(e.state);
  return `<button class="tile-power ${active ? "is-on" : ""}" data-entity="${esc(e.entity_id)}" aria-label="Turn ${esc(label(e))} ${active ? "off" : "on"}" aria-pressed="${active}" ${unavailable ? "disabled" : ""}>${svg("power")}</button>`;
}
function inlineFan(e) {
  const attrs = fanAttributes(e);
  const current = Number(attrs.percentage ?? 0);
  const supports = Number(attrs.supported_features || 0);
  const levels = supports & 1 ? fanLevels(e) : [];
  const modes =
    supports & 8 && Array.isArray(attrs.preset_modes)
      ? attrs.preset_modes.filter((mode) => typeof mode === "string")
      : [];
  return `<div class="card-fan-status"><span>${svg("wind")} ${e.state === "on" ? "Running · " + esc(attrs.preset_mode || "normal") : "Off"}</span><strong>${e.state === "on" ? Math.round(current) + "%" : "Standby"}</strong></div>
    <div class="card-fan-speeds" role="group" aria-label="${esc(label(e))} speeds">${levels.map((n, i) => `<button class="fan-speed ${Math.abs(n - current) <= 2 ? "active" : ""}" data-ha-percentage="${n}" data-ha-entity="${esc(e.entity_id)}" aria-label="Speed ${i + 1}" aria-pressed="${Math.abs(n - current) <= 2}">${i + 1}<span>${n}%</span></button>`).join("")}</div>
    ${modes.length ? `<div class="card-fan-presets" role="group" aria-label="Fan mode">${modes.map((mode) => `<button class="fan-preset ${attrs.preset_mode === mode ? "active" : ""}" data-ha-preset="${esc(mode)}" data-ha-entity="${esc(e.entity_id)}" aria-pressed="${attrs.preset_mode === mode}">${esc(mode)}</button>`).join("")}</div>` : ""}
    ${supports & 2 ? `<button class="card-oscillation ${attrs.oscillating ? "active" : ""}" data-ha-oscillate="${!attrs.oscillating}" data-ha-entity="${esc(e.entity_id)}" aria-pressed="${Boolean(attrs.oscillating)}">${svg("sliders")} ${attrs.oscillating ? "Oscillating" : "Oscillation off"}</button>` : ""}`;
}
function inlineLight(e) {
  const attrs = e.attributes || {};
  const modes = attrs.supported_color_modes || [];
  const dimmable = modes.some((mode) => mode !== "onoff");
  const rgb = modes.some((mode) =>
    ["rgb", "rgbw", "rgbww", "hs", "xy"].includes(mode),
  );
  const temp = modes.includes("color_temp");
  const value = Math.round(
    (Number(attrs.brightness ?? (e.state === "on" ? 255 : 0)) / 255) * 100,
  );
  const colour = lightColor(e);
  const min = Math.max(1500, Number(attrs.min_color_temp_kelvin || 2000));
  const max = Math.min(10000, Number(attrs.max_color_temp_kelvin || 6500));
  const kelvin = Math.max(
    min,
    Math.min(max, Number(attrs.color_temp_kelvin || 4000)),
  );
  return `<div class="card-light-summary"><span class="card-light-glow ${e.state === "on" ? "lit" : ""}" style="--lamp-color:${esc(colour)}">${svg("bulb")}</span><div><strong>${e.state === "on" ? "Light on" : "Light off"}</strong><small>${rgb ? "Colour · " : ""}${dimmable ? value + "% brightness" : "On / off"}</small></div>${rgb ? `<label class="card-color-button" title="Choose light colour"><input type="color" aria-label="Colour for ${esc(label(e))}" data-ha-color="${esc(e.entity_id)}" value="${esc(colour)}"><span style="background:${esc(colour)}"></span></label>` : ""}</div>
  ${dimmable ? `<label class="card-light-range"><span>Brightness <output>${value}%</output></span><input type="range" min="1" max="100" value="${value}" style="--lamp-color:${esc(colour)}" data-control="brightness" data-entity-id="${esc(e.entity_id)}" aria-label="Brightness for ${esc(label(e))}"></label>` : ""}
  ${temp && min < max ? `<label class="card-light-range card-temp-range"><span>White temperature <output>${kelvin} K</output></span><input type="range" min="${min}" max="${max}" step="50" value="${kelvin}" data-control="color_temp" data-entity-id="${esc(e.entity_id)}" aria-label="White temperature for ${esc(label(e))}"></label>` : ""}`;
}
function inlineCover(e) {
  const disabled = ["unknown", "unavailable"].includes(e.state);
  return `<div class="card-cover-state">${svg("sliders")} <strong>${esc(deviceState(e))}</strong></div><div class="card-cover-actions">${[
    ["open_cover", "Open"],
    ["stop_cover", "Stop"],
    ["close_cover", "Close"],
  ]
    .map(
      ([action, title]) =>
        `<button data-ha-action="${action}" data-ha-entity="${esc(e.entity_id)}" ${disabled ? "disabled" : ""}>${esc(title)}</button>`,
    )
    .join("")}</div>`;
}
function inlineClimate(e) {
  const target = Number(
    e.attributes?.temperature ?? e.attributes?.target_temp ?? 22,
  );
  const temperature = Number.isFinite(target)
    ? Math.max(10, Math.min(35, target))
    : 22;
  return `<div class="card-climate-reading"><span>${svg("sun")} ${esc(e.attributes?.current_temperature ?? e.state)}° now</span><strong>${temperature}°</strong></div><div class="card-temperature-actions"><button data-ha-temp="${temperature - 0.5}" data-ha-entity="${esc(e.entity_id)}" ${temperature <= 10 ? "disabled" : ""} aria-label="Lower target temperature">−</button><span>Target</span><button data-ha-temp="${temperature + 0.5}" data-ha-entity="${esc(e.entity_id)}" ${temperature >= 35 ? "disabled" : ""} aria-label="Raise target temperature">+</button></div>`;
}
function inlineReadings(d, limit = 2) {
  const readings = [...d.readings]
    .sort((a, b) => {
      const rank = (e) =>
        /temperature|humidity|progress|battery|air quality|power/i.test(
          label(e),
        )
          ? 0
          : 1;
      return rank(a) - rank(b);
    })
    .filter((e) => !["unknown", "unavailable"].includes(e.state));
  return readings
    .slice(0, limit)
    .map(
      (e) =>
        `<div class="card-reading"><small>${esc(label(e))}</small><strong>${esc(deviceState(e))}</strong></div>`,
    )
    .join("");
}
function inlineComplex(d) {
  const safe = d.controls
    .filter(
      (e) =>
        ["light", "switch", "fan", "input_boolean"].includes(domainOf(e)) &&
        !["unknown", "unavailable"].includes(e.state),
    )
    .sort((a, b) => priority(a) - priority(b))
    .slice(0, 2);
  return `<div class="card-complex-main"><span>${svg("apps")}</span><div><strong>${d.controls.length} controls</strong><small>${d.readings.length} live readings</small></div></div>
    ${safe.length ? `<div class="card-complex-controls">${safe.map((e) => `<div><span>${esc(label(e))}</span>${cardPower(e)}</div>`).join("")}</div>` : ""}
    ${d.readings.length ? `<div class="card-reading-row">${inlineReadings(d)}</div>` : ""}`;
}
function homeTile(d) {
  const main = d.primary;
  const kind = d.kind;
  const power = ["light", "fan", "switch", "input_boolean"].includes(
    domainOf(main),
  )
    ? main
    : null;
  const complex = kind === "mixed" || d.controls.length > 6;
  const style = complex
    ? "appliance"
    : kind === "climate"
      ? "fan"
      : kind === "light"
        ? "light"
        : kind === "cover"
          ? "cover"
          : kind === "media"
            ? "media"
            : kind === "sensor"
              ? "sensor"
              : kind === "power"
                ? "switch"
                : "other";
  const wide = ["fan", "light", "appliance", "cover"].includes(style);
  let controls = "";
  if (style === "fan")
    controls =
      domainOf(main) === "climate" ? inlineClimate(main) : inlineFan(main);
  else if (style === "light") controls = inlineLight(main);
  else if (style === "cover") controls = inlineCover(main);
  else if (style === "appliance") controls = inlineComplex(d);
  else if (style === "sensor")
    controls = `<div class="card-reading-row">${inlineReadings(d, 2)}</div>`;
  else if (style === "switch")
    controls = `<div class="card-switch-status">${svg("power")} ${main.state === "on" ? "Powered on" : "Powered off"}</div>`;
  else if (style === "media")
    controls = `<div class="card-media-state">${svg("play")} ${esc(deviceState(main))}</div><button class="card-media-play" data-ha-action="media_play_pause" data-ha-entity="${esc(main.entity_id)}" ${["unknown", "unavailable"].includes(main.state) ? "disabled" : ""}>Play / pause</button>`;
  else
    controls = `<div class="card-reading-row">${inlineReadings(d, 2) || esc(deviceSummaryLine(d))}</div>`;
  const disabled = ["unknown", "unavailable"].includes(main.state);
  return `<article class="home-tile control-card control-card--${style} tone-${kind} ${wide ? "card-wide" : "card-compact"} ${main.state === "on" ? "is-on" : ""}">
    <header class="control-card-header"><button class="tile-open" data-device="${esc(d.id)}" aria-label="Open details for ${esc(d.name)}"><span class="tile-icon">${svg(domainIcon(domainOf(main)))}</span><span class="control-card-title"><small>${esc(d.room)}${d.favourite ? " · ✦" : ""}</small><strong>${esc(d.name)}</strong></span></button>
    ${style === "appliance" || style === "sensor" || style === "cover" || style === "media" || style === "other" || !power ? `<button class="tile-detail" data-device="${esc(d.id)}" aria-label="Details for ${esc(d.name)}">${svg("chevron")}</button>` : cardPower(power)}</header>
    <div class="control-card-content">${controls}</div>
    <footer class="control-card-footer"><span>${style === "sensor" ? "Sensor" : style === "appliance" ? "Device overview" : style === "fan" ? "Speed & airflow" : style === "light" ? "Lighting" : style === "cover" ? "Shades & blinds" : style === "switch" ? "Power" : "Device"}</span><button data-device="${esc(d.id)}" aria-label="More options for ${esc(d.name)}">More controls ${svg("arrow")}</button></footer>
  </article>`;
}
function roomPills() {
  const rooms = ["All", "Favorites", ...homeRooms(), "Unassigned", "Sensors"];
  return rooms
    .map(
      (room) =>
        `<button class="room-pill ${room === state.room ? "selected" : ""}" data-room="${esc(room)}" aria-pressed="${room === state.room}">${room === "Favorites" ? svg("spark") : ""}${esc(room)}</button>`,
    )
    .join("");
}
function home() {
  const all = homeDevices(),
    active = all.filter((d) => d.controls.some((e) => e.state === "on")).length;
  return `<div class="home-heading"><div><div class="eyebrow">YOUR SPACE</div><h1>Smart Home</h1><p>Your favourite controls, right where you need them.</p></div><button class="home-refresh" data-refresh="true" aria-label="Refresh devices">${svg("activity")}</button></div>
  ${
    !state.me.credentials.homeassistant
      ? `<section class="panel">${empty("Connect Home Assistant in Settings to control your home.", "lock")}${linkPage("settings", "Connect")}</section>`
      : state.haError
        ? `<section class="panel">${empty(state.haError, "activity")}</section>`
        : state.entities === null
          ? '<div class="loadingline"></div>'
          : `
  <div class="home-status"><span class="status-dot"></span>${active} active devices <span class="status-sep">·</span> ${all.length} devices <span class="status-sep">·</span> ${homeRooms().length} rooms</div>
  <div class="home-toolbar"><label class="home-find">${svg("search")}<input id="home-search" placeholder="Find a device, control, or room" value="${esc(state.homeSearch)}" autocomplete="off" aria-label="Find a device"></label><button class="home-room-button" data-open="rooms" aria-label="Choose room">${svg("sliders")}</button></div>
  <div class="room-pills" aria-label="Filter by room">${roomPills()}</div><div class="home-section-title"><strong>${esc(state.room === "All" ? "Your devices" : state.room)}</strong><span id="home-count">${homeItems().length} devices</span></div>
  <div class="home-grid" id="home-grid">${homeItems().map(homeTile).join("") || empty("No matching devices", "search")}</div>
  <div class="home-thumb-dock"><button data-room="Favorites" aria-label="Favourites">${svg("spark")}<span>Favourites</span></button><button data-open="rooms" aria-label="Rooms">${svg("sliders")}<span>Rooms</span></button></div>`
  }`;
}
function lightColor(e) {
  const rgb = e.attributes?.rgb_color;
  if (
    Array.isArray(rgb) &&
    rgb.length === 3 &&
    rgb.every((value) => Number.isFinite(Number(value)))
  )
    return (
      "#" +
      rgb
        .map((c) =>
          Math.max(0, Math.min(255, Math.round(c)))
            .toString(16)
            .padStart(2, "0"),
        )
        .join("")
    );
  const kelvin = Number(e.attributes?.color_temp_kelvin);
  if (kelvin > 0)
    return kelvin >= 4200 ? "#b9d7ff" : kelvin >= 3200 ? "#ffe7bc" : "#ffbc74";
  return "#f4d9aa";
}
function fanLevels(e) {
  const step = Number(e.attributes?.percentage_step);
  const count =
    step > 0 && step <= 100
      ? Math.min(10, Math.max(1, Math.round(100 / step)))
      : 3;
  return Array.from({ length: count }, (_, index) =>
    Math.round(((index + 1) * 100) / count),
  );
}
function fanAttributes(e) {
  const pending = state.fanFeedback[e.entity_id];
  if (!pending) return e.attributes || {};
  return {
    ...(e.attributes || {}),
    ...Object.fromEntries(
      Object.entries(pending).map(([field, update]) => [field, update.value]),
    ),
  };
}
function reconcileFanFeedback(entities) {
  const current = new Map(entities.map((entity) => [entity.entity_id, entity]));
  for (const [entity, fields] of Object.entries(state.fanFeedback)) {
    const reported = current.get(entity)?.attributes;
    for (const [field, update] of Object.entries(fields)) {
      const match =
        reported &&
        (field === "percentage"
          ? Math.abs(Number(reported[field]) - update.value) <= 2
          : reported[field] === update.value);
      if (
        match ||
        (update.acknowledged && Date.now() - update.startedAt > 7000)
      ) {
        delete fields[field];
        if (!match && update.acknowledged && state.device)
          toast("Home Assistant has not confirmed that fan setting", true);
      }
    }
    if (!Object.keys(fields).length) delete state.fanFeedback[entity];
  }
}
function fanPanel(e) {
  const id = esc(e.entity_id),
    attrs = fanAttributes(e);
  const current = Number(attrs.percentage || 0),
    levels = fanLevels(e);
  const modes = Array.isArray(attrs.preset_modes)
    ? attrs.preset_modes.filter((v) => typeof v === "string")
    : [];
  const supports = Number(attrs.supported_features || 0);
  const speed =
    supports & 1
      ? `<div class="control-block"><div class="control-heading"><strong>Fan speed</strong><span>${current > 0 ? Math.round(current) + "%" : "Off"}</span></div><div class="fan-speeds" role="group" aria-label="Fan speed">${levels.map((n, i) => `<button class="fan-speed ${Math.abs(n - current) <= 2 ? "active" : ""}" data-ha-percentage="${n}" data-ha-entity="${id}" aria-pressed="${Math.abs(n - current) <= 2}"><strong>${i + 1}</strong><small>${n}%</small></button>`).join("")}</div></div>`
      : "";
  const presets =
    supports & 8 && modes.length
      ? `<div class="control-block"><div class="control-heading"><strong>Mode</strong><span>${esc(attrs.preset_mode || "")}</span></div><div class="fan-presets">${modes.map((mode) => `<button class="fan-preset ${attrs.preset_mode === mode ? "active" : ""}" data-ha-preset="${esc(mode)}" data-ha-entity="${id}" aria-pressed="${attrs.preset_mode === mode}">${esc(mode)}</button>`).join("")}</div></div>`
      : "";
  const oscillation =
    supports & 2
      ? `<div class="control-block"><div class="control-heading"><strong>Horizontal oscillation</strong><span>${attrs.oscillating ? "On" : "Off"}</span></div><button class="control-switch ${attrs.oscillating ? "on" : ""}" data-ha-oscillate="${!attrs.oscillating}" data-ha-entity="${id}" aria-label="Toggle horizontal oscillation" aria-pressed="${Boolean(attrs.oscillating)}">${svg("sliders")} ${attrs.oscillating ? "Oscillating" : "Start oscillation"}</button></div>`
      : "";
  const on = e.state === "on";
  return `<div class="capability-panel tone-climate" data-fan-entity="${id}"><div class="fan-hero">
    <div class="fan-gauge" style="--fan-percent:${on ? current : 0}%"><span>${svg("wind")}</span></div>
    <div class="fan-state"><strong>${on ? "Fan running" : "Fan off"}</strong><small>${on ? Math.round(current) + "% · " + esc(attrs.preset_mode || "normal") : "Ready to start"}</small></div>
    <button class="control-switch ${on ? "on" : ""}" data-entity="${id}" aria-label="Turn fan ${on ? "off" : "on"}" aria-pressed="${on}">${svg("power")}</button>
  </div>${speed}${presets}${oscillation}</div>`;
}
function lightPanel(e) {
  const id = esc(e.entity_id),
    attrs = e.attributes || {};
  const modes = attrs.supported_color_modes || [],
    active = e.state === "on";
  const color = lightColor(e);
  const brightness = Math.round((Number(attrs.brightness ?? 255) / 255) * 100);
  const dimmable = modes.some((v) => v !== "onoff");
  const rgb = modes.some((v) =>
    ["rgb", "rgbw", "rgbww", "hs", "xy"].includes(v),
  );
  const temperature = modes.includes("color_temp");
  const min = Math.max(1500, Number(attrs.min_color_temp_kelvin || 2000));
  const max = Math.min(10000, Number(attrs.max_color_temp_kelvin || 6500));
  const current = Math.max(
    min,
    Math.min(max, Number(attrs.color_temp_kelvin || 4000)),
  );
  const effects = Array.isArray(attrs.effect_list)
    ? attrs.effect_list.filter((v) => typeof v === "string")
    : [];
  return `<div class="capability-panel tone-light">
    <div class="light-hero"><div class="light-preview ${active ? "glowing" : ""}" style="--lamp-color:${esc(color)}">${svg("bulb")}</div><div><strong>${active ? "Light on" : "Light off"}</strong><small>${rgb ? "Full colour" : temperature ? "Tunable white" : dimmable ? "Dimmable" : "On / Off"}</small></div><button class="control-switch ${active ? "on" : ""}" data-entity="${id}" aria-label="Toggle light" aria-pressed="${active}">${svg("power")}</button></div>
    ${dimmable ? `<label class="control-block light-brightness"><div class="control-heading"><strong>Brightness</strong><output>${brightness}%</output></div><input type="range" min="1" max="100" value="${brightness}" data-control="brightness" data-entity-id="${id}" style="--lamp-color:${esc(color)}"></label>` : ""}
    ${rgb ? `<label class="control-block light-colour"><div class="control-heading"><strong>Colour</strong><span>Tap to choose</span></div><div class="colour-picker"><input type="color" value="${esc(color)}" data-ha-color="${id}" aria-label="Choose light colour"><span class="colour-indicator" style="background:${esc(color)}"></span><span>${esc(color.toUpperCase())}</span></div></label>` : ""}
    ${temperature && min < max ? `<label class="control-block light-temperature"><div class="control-heading"><strong>White temperature</strong><output>${current} K</output></div><input type="range" min="${min}" max="${max}" step="50" value="${current}" data-control="color_temp" data-entity-id="${id}"><div class="temperature-labels"><span>Warm</span><span>Cool</span></div></label>` : ""}
    ${effects.length ? `<label class="control-block"><div class="control-heading"><strong>Effect</strong><span>${effects.length} options</span></div><select data-ha-effect="${id}" aria-label="Light effect"><option value="">Choose effect</option>${effects.map((v) => `<option value="${esc(v)}" ${attrs.effect === v ? "selected" : ""}>${esc(v)}</option>`).join("")}</select></label>` : ""}
  </div>`;
}
function controlRow(e) {
  const domain = domainOf(e),
    disabled = ["unknown", "unavailable"].includes(e.state),
    id = esc(e.entity_id);
  if (domain === "light")
    return `<div class="device-control feature-control">${lightPanel(e)}</div>`;
  if (domain === "fan")
    return `<div class="device-control feature-control">${fanPanel(e)}</div>`;
  const title = `<span class="control-label"><strong>${esc(label(e))}</strong><small>${esc(deviceState(e))}</small></span>`;
  let action = "";
  if (["switch", "input_boolean"].includes(domain))
    action = `<button class="control-toggle ${e.state === "on" ? "on" : ""}" data-entity="${id}" aria-label="Toggle ${esc(label(e))}" ${disabled ? "disabled" : ""}>${svg("power")}</button>`;
  else if (domain === "cover")
    action = `<div class="control-actions">${["open_cover", "stop_cover", "close_cover"].map((a) => `<button data-ha-action="${a}" data-ha-entity="${id}">${a.split("_")[0]}</button>`).join("")}</div>`;
  else if (["scene", "button"].includes(domain))
    action = `<button class="control-action" data-ha-action="${domain === "scene" ? "turn_on" : "press"}" data-ha-entity="${id}" ${domain === "button" ? 'data-confirm="true"' : ""} ${disabled ? "disabled" : ""}>${domain === "scene" ? "Activate" : "Press"}</button>`;
  else if (domain === "select") {
    const options = Array.isArray(e.attributes?.options)
      ? e.attributes.options.filter((v) => typeof v === "string")
      : [];
    action = `<select data-ha-select="${id}" aria-label="${esc(label(e))}" ${disabled ? "disabled" : ""}>${options.map((v) => `<option value="${esc(v)}" ${v === e.state ? "selected" : ""}>${esc(v)}</option>`).join("")}</select>`;
  } else if (domain === "number") {
    const min = Number(e.attributes?.min ?? 0),
      max = Number(e.attributes?.max ?? 100),
      step = Number(e.attributes?.step ?? 1);
    if (Number.isFinite(min) && Number.isFinite(max) && min < max)
      action = `<input class="number-control" type="number" data-ha-number="${id}" aria-label="${esc(label(e))}" min="${min}" max="${max}" step="${step > 0 ? step : 1}" value="${esc(e.state)}" ${disabled ? "disabled" : ""}>`;
  } else if (domain === "media_player")
    action = `<button class="control-action" data-ha-action="media_play_pause" data-ha-entity="${id}" ${disabled ? "disabled" : ""}>Play / Pause</button>`;
  else if (domain === "climate")
    action = `<form class="control-temp" data-ha-climate="${id}"><input type="number" min="10" max="35" step=".5" value="${Number(e.attributes?.temperature) || 22}" aria-label="Target temperature" ${disabled ? "disabled" : ""}><button type="submit" ${disabled ? "disabled" : ""}>Set</button></form>`;
  return `<div class="device-control"><div class="device-control-main"><span class="control-symbol">${svg(domainIcon(domain))}</span>${title}${action}</div></div>`;
}
function deviceSheet() {
  const d = homeDevices().find((item) => item.id === state.device);
  if (!d) return "";
  const primary = d.primary;
  const favourites = d.favourite;
  const readings = d.readings;
  const detailed = d.controls.slice().sort((a, b) => priority(a) - priority(b));
  const alerts = d.entities.filter(
    (e) => e.state === "unavailable" || e.state === "unknown",
  ).length;
  const extra = d.entities.filter(
    (e) =>
      !isActionable(e) && !["sensor", "binary_sensor"].includes(domainOf(e)),
  ).length;
  return `<div class="overlay" data-dismiss="true"><section class="sheet device-sheet group-sheet tone-${d.kind}" role="dialog" aria-label="${esc(d.name)}"><div class="sheet-grip"></div>
    <div class="between"><div class="eyebrow">${esc(d.room)} · ${d.entities.length} entities</div><button class="icon-btn" data-close="true" aria-label="Close">${svg("x")}</button></div>
    <div class="detail-head"><span class="detail-hero-icon">${svg(d.kind === "mixed" ? "apps" : domainIcon(domainOf(primary)))}</span><div><h2>${esc(d.name)}</h2><p>${esc(d.model || deviceSummaryLine(d))}</p></div></div>
    <div class="detail-tools"><button data-favorite="${esc(d.key)}" aria-pressed="${favourites}">${svg("spark")} ${favourites ? "Favourited" : "Favourite"}</button><label>Room <input id="room-name" list="home-room-names" value="${esc(d.room === "Unassigned" ? "" : d.room)}" maxlength="48" placeholder="Assign room"></label><datalist id="home-room-names">${homeRooms()
      .map((r) => `<option value="${esc(r)}"></option>`)
      .join(
        "",
      )}</datalist><button data-save-room="${esc(d.key)}" aria-label="Save room">${svg("check")}</button></div>
    ${alerts ? `<div class="device-alert">${alerts} entities currently unavailable</div>` : ""}
    ${detailed.length ? `<div class="device-section-title">Controls <span>${detailed.length}</span></div><div class="controls-stack">${detailed.map(controlRow).join("")}</div>` : ""}
    ${
      readings.length
        ? `<div class="device-section-title">Readings <span>${readings.length}</span></div><div class="readings-grid">${readings
            .slice(0, state.showReadings ? 100 : 6)
            .map(
              (e) =>
                `<div class="reading"><small>${esc(label(e))}</small><strong>${esc(deviceState(e))}</strong></div>`,
            )
            .join(
              "",
            )}</div>${readings.length > 6 ? `<button class="show-readings" data-expand-readings="true">${state.showReadings ? "Show fewer" : "Show all " + readings.length + " readings"}</button>` : ""}`
        : ""
    }
    ${extra ? `<p class="device-meta-note">${extra} informational or maintenance entities are available in Home Assistant.</p>` : ""}
    </section></div>`;
}
function roomsSheet() {
  return `<div class="overlay" data-dismiss="true"><section class="sheet rooms-sheet" role="dialog" aria-label="Choose room"><div class="sheet-grip"></div><div class="between"><h2>Choose a room</h2><button class="icon-btn" data-close="true" aria-label="Close">${svg("x")}</button></div><div class="room-choice-list">${["All", "Favorites", ...homeRooms(), "Unassigned", "Sensors"].map((room) => `<button data-room="${esc(room)}">${room === state.room ? svg("check") : svg("home")} ${esc(room)}</button>`).join("")}</div></section></div>`;
}
async function saveHomePrefs() {
  await api("/api/profile/home", "PUT", {
    favorites: state.me.favorites || [],
    rooms: state.me.rooms || {},
    hand: state.me.hand || "right",
  });
}
function mediaQueue() {
  return ["sonarr", "radarr"].flatMap((service) =>
    (state.arr[service]?.records || []).map((item) => ({ ...item, service })),
  );
}
function mediaNeedsAttention(item) {
  const status = String(item.status || "").toLowerCase();
  return (
    Boolean(item.errorMessage) || /warning|failed|error|stalled/.test(status)
  );
}
function mediaStatus(item) {
  const status = String(item.status || "queued");
  if (mediaNeedsAttention(item)) return "Needs attention";
  if (/download/i.test(status)) return "Downloading";
  if (/queue/i.test(status)) return "Queued";
  if (/import/i.test(status)) return "Importing";
  return status.replace(/([A-Z])/g, " $1").trim();
}
function mediaProgress(item) {
  const size = Number(item.size),
    left = Number(item.sizeleft);
  return Number.isFinite(size) && size > 0 && Number.isFinite(left)
    ? Math.min(100, Math.max(0, Math.round((1 - left / size) * 100)))
    : null;
}
function mediaItems() {
  return mediaQueue().filter(
    (r) =>
      state.mediaFilter === "All" ||
      (state.mediaFilter === "Television" && r.service === "sonarr") ||
      (state.mediaFilter === "Movies" && r.service === "radarr") ||
      (state.mediaFilter === "Attention" && mediaNeedsAttention(r)),
  );
}
function mediaShortcut(id, title, detail, iconName, tone) {
  const app = state.catalog.find((a) => a.id === id);
  if (!app) return "";
  return `<a class="media-shortcut tone-${tone}" href="${esc(app.url)}" target="_blank" rel="noopener noreferrer"><span class="media-shortcut-icon">${svg(iconName)}</span><span><strong>${esc(title)}</strong><small>${esc(detail)}</small></span>${svg("external")}</a>`;
}
function mediaRow(item) {
  const progress = mediaProgress(item),
    issue = mediaNeedsAttention(item);
  const tv = item.service === "sonarr";
  return `<article class="media-queue-row ${issue ? "needs-attention" : ""}">
    <span class="media-poster tone-${tv ? "media" : "warm"}">${svg(tv ? "play" : "image")}</span>
    <div class="media-queue-main"><div class="media-row-header"><span class="media-type">${tv ? "SERIES · SONARR" : "MOVIE · RADARR"}</span><span class="media-status ${issue ? "warn" : ""}">${svg(issue ? "activity" : "download")}${mediaStatus(item)}</span></div>
      <strong>${esc(item.title || "Untitled download")}</strong><div class="media-row-meta">${item.timeleft ? `About ${esc(item.timeleft)} remaining` : "Status from your download queue"}${progress !== null ? ` · ${progress}%` : ""}</div>
      ${progress !== null ? `<div class="media-progress"><span style="width:${progress}%"></span></div>` : ""}
      ${item.errorMessage ? `<p class="media-error">${esc(item.errorMessage)}</p>` : ""}</div>
  </article>`;
}
function media() {
  const connected = ["sonarr", "radarr"].filter(
    (key) => state.me.credentials[key],
  );
  const full = mediaQueue();
  const attention = full.filter(mediaNeedsAttention).length;
  const total = ["sonarr", "radarr"].reduce(
    (n, key) => n + (state.arr[key]?.totalRecords || 0),
    0,
  );
  const downloading = full.filter(
    (r) => /download/i.test(r.status || "") && !mediaNeedsAttention(r),
  ).length;
  return `<div class="media-heading"><div class="eyebrow">ENTERTAINMENT</div><h1>Media <span>hub.</span></h1><p>Your requests, downloads and library in one quieter place.</p></div>
    <div class="media-spotlight"><div><span class="media-spotlight-label">IN THE PIPELINE</span><strong>${total || full.length}</strong><p>${total === 1 ? "item" : "items"} currently queued</p></div><div class="media-spotlight-metrics"><div><strong>${downloading}</strong><span>Downloading</span></div><div><strong>${attention}</strong><span>Need attention</span></div></div></div>
    <div class="media-launchers">${[
      ["jellyfin", "Watch", "Open your library", "play", "media"],
      ["seerr", "Discover", "Find something new", "search", "warm"],
      ["sonarr", "Television", "Manage series", "play", "cool"],
      ["radarr", "Movies", "Manage films", "image", "rose"],
      ...state.catalog
        .filter(
          (a) =>
            a.page === "media" &&
            !["jellyfin", "seerr", "sonarr", "radarr"].includes(a.id),
        )
        .map((a) => [
          a.id,
          a.name,
          a.category,
          logoFor(a),
          {
            bazarr: "rose",
            transmission: "cool",
            prowlarr: "warm",
            streamystats: "media",
          }[a.id] || "media",
        ]),
    ]
      .map((item) => mediaShortcut(...item))
      .join("")}</div>
    <section class="media-activity"><div class="media-activity-head"><div><div class="eyebrow">DOWNLOAD ACTIVITY</div><h2>What’s moving</h2></div><button class="home-refresh" data-refresh="true" aria-label="Refresh downloads">${svg("activity")}</button></div>
      <div class="media-tabs" aria-label="Filter downloads">${["All", "Television", "Movies", "Attention"].map((kind) => `<button class="media-tab ${state.mediaFilter === kind ? "active" : ""}" data-media-filter="${kind}" aria-pressed="${state.mediaFilter === kind}">${esc(kind)}${kind === "Attention" && attention ? `<span>${attention}</span>` : ""}</button>`).join("")}</div>
      ${connected.length ? (mediaItems().length ? `<div class="media-feed">${mediaItems().map(mediaRow).join("")}</div>` : `<div class="media-empty"><span>${svg(state.mediaFilter === "Attention" ? "check" : "download")}</span><strong>${state.mediaFilter === "Attention" ? "Nothing needs attention" : "Nothing in this queue"}</strong><p>${state.mediaFilter === "Attention" ? "No reported download errors right now." : "Your media activity will appear here when downloads begin."}</p></div>`) : `<div class="media-empty"><span>${svg("lock")}</span><strong>Connect your media managers</strong><p>Add your personal Sonarr and Radarr keys in Settings to see live downloads.</p>${linkPage("settings", "Connect services")}</div>`}
      ${state.arrError ? `<p class="media-error">${esc(state.arrError)}</p>` : ""}
    </section>`;
}
function logoFor(a) {
  return (
    {
      ha: "home",
      jellyfin: "play",
      sonarr: "play",
      radarr: "play",
      prowlarr: "search",
      seerr: "play",
      streamystats: "activity",
      gerrit: "server",
      onedev: "server",
      agentmail: "doc",
      ntfy: "activity",
      computer: "server",
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
function appTone(category) {
  return (
    {
      "Smart home": "light",
      Media: "media",
      Photos: "rose",
      Documents: "cool",
      Automation: "warm",
      AI: "mixed",
      Development: "cool",
      Networking: "power",
    }[category] || "other"
  );
}
function serviceRow(a) {
  let host;
  try {
    host = new URL(a.url).host;
  } catch {
    host = "";
  }
  return `<a class="service-card app-card tone-${appTone(a.category)}" href="${esc(a.url)}" target="_blank" rel="noopener noreferrer" aria-label="Open ${esc(a.name)}">
    <span class="app-symbol">${svg(logoFor(a))}</span><span class="app-info"><strong>${esc(a.name)}</strong><small>${esc(a.category)}</small><span class="app-host">${esc(host)}</span></span><span class="app-link">${svg("external")}</span></a>`;
}
function serviceCards(items) {
  return `<div class="apps-grid">${items.length ? items.map(serviceRow).join("") : empty("No applications match this filter.", "search")}</div>`;
}
function appCategories() {
  return ["All", ...new Set(state.catalog.map((a) => a.category))];
}
function appMatches() {
  return state.catalog.filter(
    (a) =>
      (state.appCategory === "All" || a.category === state.appCategory) &&
      (!state.search ||
        [a.name, a.category, a.url].some((part) =>
          part.toLowerCase().includes(state.search.toLowerCase()),
        )),
  );
}
function applications() {
  return `<div class="apps-heading"><div class="eyebrow">YOUR SERVER</div><h1>Applications<span class="app-total">${state.catalog.length}</span></h1><p>All your deployed web interfaces, in one place.</p></div>
    <div class="apps-find">${svg("search")}<input id="app-search" placeholder="Find a service…" value="${esc(state.search)}" aria-label="Search applications" autocomplete="off"></div>
    <div class="app-categories">${appCategories()
      .map(
        (category) =>
          `<button data-app-category="${esc(category)}" class="room-pill ${state.appCategory === category ? "selected" : ""}" aria-pressed="${state.appCategory === category}">${esc(category)}</button>`,
      )
      .join("")}</div>
    <div class="home-section-title"><strong>${esc(state.appCategory === "All" ? "All services" : state.appCategory)}</strong><span id="apps-count">${appMatches().length} apps</span></div>
    <div id="apps-results">${serviceCards(appMatches())}</div>`;
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
    '<div class="appearance-label">One-handed controls</div><div class="hand-options"><button data-hand="right" aria-pressed="' +
    ((state.me.hand || "right") === "right") +
    '">Right hand</button><button data-hand="left" aria-pressed="' +
    (state.me.hand === "left") +
    '">Left hand</button></div>' +
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
      .filter((n) => ["overview", "home", "media", "apps"].includes(n[0]))
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
      apps: applications,
      settings,
      admin,
    }[state.page]?.() || overview()
  );
}
function move(page) {
  state.quick = false;
  state.device = null;
  state.roomPicker = false;
  state.help = false;
  state.keyboardTarget = "";
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
          reconcileFanFeedback(v);
          state.entities = v;
          state.haError = "";
        })
        .catch((e) => {
          state.haError = e.message;
          state.entities = [];
        }),
    );
  if (
    (page === "home" || page === "overview") &&
    has("home") &&
    state.me.credentials.homeassistant &&
    !state.areasLoaded
  ) {
    state.areasLoaded = true;
    jobs.push(
      api("/api/ha/areas")
        .then((v) => {
          state.areas = v || {};
        })
        .catch(() => {
          state.areas = {};
        }),
    );
  }
  if (
    (page === "home" || page === "overview") &&
    has("home") &&
    state.me.credentials.homeassistant &&
    !state.deviceRegistryLoaded
  ) {
    state.deviceRegistryLoaded = true;
    jobs.push(
      api("/api/ha/devices")
        .then((v) => {
          state.deviceRegistry = v || {};
        })
        .catch(() => {
          state.deviceRegistry = {};
          state.deviceRegistryLoaded = false;
        }),
    );
  }
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
  if (page === "admin" && state.me.admin)
    jobs.push(
      api("/api/users").then((v) => {
        state.users = v;
      }),
    );
  await Promise.allSettled(jobs);
  const editing = document.activeElement?.matches(
    "#home-search, .device-sheet input, .home-grid input",
  );
  if (state.page === page && !editing) {
    const previousScroll = document.querySelector(".device-sheet")?.scrollTop;
    render();
    const sheet = document.querySelector(".device-sheet");
    if (sheet && previousScroll != null) sheet.scrollTop = previousScroll;
  }
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
  if (target.dataset.mediaFilter) {
    state.mediaFilter = target.dataset.mediaFilter;
    render();
    return;
  }
  if (target.dataset.room) {
    state.room = target.dataset.room;
    state.roomPicker = false;
    render();
    return;
  }
  if (target.dataset.appCategory) {
    state.appCategory = target.dataset.appCategory;
    render();
    return;
  }
  if (target.dataset.open === "rooms") {
    state.device = null;
    state.quick = false;
    state.roomPicker = true;
    render();
    return;
  }
  if (target.dataset.device) {
    state.device = target.dataset.device;
    state.showReadings = false;
    state.roomPicker = false;
    state.quick = false;
    render();
    if (state.keyboardMode && desktopKeyboard())
      document
        .querySelector(
          ".device-sheet .fan-hero [data-entity], .device-sheet .light-hero [data-entity], .device-sheet .control-toggle, .device-sheet .fan-speed, .device-sheet .device-control button",
        )
        ?.focus();
    return;
  }
  if (target.dataset.favorite) {
    const previous = [...(state.me.favorites || [])];
    const group = homeDevices().find((d) =>
      d.entities.some((e) => e.entity_id === target.dataset.favorite),
    );
    const ids = new Set((group?.entities || []).map((e) => e.entity_id));
    state.me.favorites = group?.favourite
      ? previous.filter((id) => !ids.has(id))
      : [...previous, target.dataset.favorite];
    render();
    try {
      await saveHomePrefs();
    } catch (err) {
      state.me.favorites = previous;
      render();
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.saveRoom) {
    const name = document.getElementById("room-name")?.value.trim() || "";
    const previous = { ...(state.me.rooms || {}) };
    state.me.rooms = { ...previous };
    if (name) state.me.rooms[target.dataset.saveRoom] = name;
    else delete state.me.rooms[target.dataset.saveRoom];
    render();
    try {
      await saveHomePrefs();
    } catch (err) {
      state.me.rooms = previous;
      render();
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.hand) {
    const previous = state.me.hand || "right";
    state.me.hand = target.dataset.hand;
    render();
    try {
      await saveHomePrefs();
    } catch (err) {
      state.me.hand = previous;
      render();
      toast(err.message, true);
    }
    return;
  }
  if (target.dataset.expandReadings) {
    state.showReadings = !state.showReadings;
    render();
    return;
  }
  if (
    target.dataset.haPercentage ||
    target.dataset.haPreset ||
    target.dataset.haOscillate
  ) {
    const entity = target.dataset.haEntity;
    const body = target.dataset.haPercentage
      ? {
          entity,
          action: "percentage",
          percentage: Number(target.dataset.haPercentage),
        }
      : target.dataset.haPreset
        ? {
            entity,
            action: "preset_mode",
            preset_mode: target.dataset.haPreset,
          }
        : {
            entity,
            action: "oscillate",
            oscillating: target.dataset.haOscillate === "true",
          };
    const field =
      body.action === "percentage"
        ? "percentage"
        : body.action === "preset_mode"
          ? "preset_mode"
          : "oscillating";
    const value = body[field];
    const sequence = ++state.fanSequence;
    if (!state.fanFeedback[entity]) state.fanFeedback[entity] = {};
    const pending = state.fanFeedback[entity];
    const previous = pending[field];
    pending[field] = {
      value,
      sequence,
      startedAt: Date.now(),
      acknowledged: false,
    };
    // Give immediate feedback, not the result of an eventually consistent HA read.
    const focusKey = target.dataset.haPercentage
      ? "haPercentage"
      : target.dataset.haPreset
        ? "haPreset"
        : "haOscillate";
    const focusValue = target.dataset[focusKey];
    const scroll = document.querySelector(".device-sheet")?.scrollTop;
    render();
    const sheet = document.querySelector(".device-sheet");
    if (sheet && scroll != null) sheet.scrollTop = scroll;
    [...(sheet?.querySelectorAll("button") || [])]
      .find(
        (button) =>
          button.dataset[focusKey] === focusValue &&
          button.dataset.haEntity === entity,
      )
      ?.focus({ preventScroll: true });
    try {
      await api("/api/ha/action", "POST", body);
      if (state.fanFeedback[entity]?.[field]?.sequence !== sequence) return;
      state.fanFeedback[entity][field].acknowledged = true;
      // Reads may initially report the old speed; the pending selection survives them.
      refreshPage("home");
      for (const delay of [1200, 3500, 7200]) {
        setTimeout(() => {
          if (
            state.me &&
            state.page === "home" &&
            state.fanFeedback[entity]?.[field]?.sequence === sequence
          )
            refreshPage("home");
        }, delay);
      }
    } catch (err) {
      if (state.fanFeedback[entity]?.[field]?.sequence === sequence) {
        if (previous?.acknowledged && Date.now() - previous.startedAt < 7000)
          state.fanFeedback[entity][field] = previous;
        else delete state.fanFeedback[entity][field];
        if (!Object.keys(state.fanFeedback[entity]).length)
          delete state.fanFeedback[entity];
        const scroll = document.querySelector(".device-sheet")?.scrollTop;
        render();
        const sheet = document.querySelector(".device-sheet");
        if (sheet && scroll != null) sheet.scrollTop = scroll;
        toast(err.message, true);
        refreshPage("home");
      }
    }
    return;
  }
  if (target.dataset.haTemp) {
    target.disabled = true;
    try {
      await api("/api/ha/action", "POST", {
        entity: target.dataset.haEntity,
        action: "set_temperature",
        temperature: Number(target.dataset.haTemp),
      });
      refreshPage("home");
    } catch (err) {
      toast(err.message, true);
      target.disabled = false;
    }
    return;
  }
  if (target.dataset.haAction) {
    if (target.dataset.confirm && !confirm("Run this device action?")) return;
    target.disabled = true;
    try {
      await api("/api/ha/action", "POST", {
        entity: target.dataset.haEntity,
        action: target.dataset.haAction,
      });
      toast("Action sent");
      refreshPage("home");
    } catch (err) {
      toast(err.message, true);
      target.disabled = false;
    }
    return;
  }
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
  if (target.dataset.open === "help") {
    state.quick = false;
    state.device = null;
    state.roomPicker = false;
    state.help = true;
    render();
    return;
  }
  if (target.dataset.open === "quick") {
    state.device = null;
    state.roomPicker = false;
    state.quick = true;
    render();
    return;
  }
  if (target.dataset.open === "search") {
    state.device = null;
    state.roomPicker = false;
    state.quick = false;
    render();
    root.insertAdjacentHTML("beforeend", searchSheet());
    document.getElementById("command-input")?.focus();
    renderResults("");
    return;
  }
  if (target.dataset.close || (target.dataset.dismiss && e.target === target)) {
    state.quick = false;
    state.roomPicker = false;
    state.device = null;
    state.help = false;
    render();
    return;
  }
  if (target.dataset.entity) {
    const entity = target.dataset.entity;
    target.disabled = true;
    try {
      const existing = state.entities.find((d) => d.entity_id === entity);
      await api("/api/ha/action", "POST", {
        entity,
        action: existing?.state === "on" ? "turn_off" : "turn_on",
      });
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
      state.fanFeedback = {};
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
      state.areas = {};
      state.areasLoaded = false;
      state.deviceRegistry = {};
      state.deviceRegistryLoaded = false;
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
document.addEventListener("input", (e) => {
  if (e.target.id === "command-input") renderResults(e.target.value);
  if (e.target.id === "app-search") {
    state.search = e.target.value;
    const node = document.getElementById("apps-results");
    if (node) node.innerHTML = serviceCards(appMatches());
    const count = document.getElementById("apps-count");
    if (count) count.textContent = `${appMatches().length} apps`;
  }
  if (e.target.id === "home-search") {
    state.homeSearch = e.target.value;
    const node = document.getElementById("home-grid");
    if (node)
      node.innerHTML =
        homeItems().map(homeTile).join("") ||
        empty("No matching devices", "search");
    const count = document.getElementById("home-count");
    if (count) count.textContent = `${homeItems().length} devices`;
  }
  if (e.target.dataset.control) {
    const output = e.target.closest("label")?.querySelector("output");
    if (output)
      output.textContent = `${e.target.value}${e.target.dataset.control === "color_temp" ? " K" : "%"}`;
  }
});
document.addEventListener("submit", async (e) => {
  if (!e.target.matches(".control-temp") && e.target.id !== "climate-form")
    return;
  e.preventDefault();
  const form = e.target;
  const btn = form.querySelector("button");
  btn.disabled = true;
  try {
    await api("/api/ha/action", "POST", {
      entity: form.dataset.haClimate || form.dataset.entityId,
      action: "set_temperature",
      temperature: Number(form.querySelector("input")?.value),
    });
    toast("Temperature updated");
    refreshPage("home");
  } catch (err) {
    toast(err.message, true);
  } finally {
    btn.disabled = false;
  }
});
document.addEventListener("change", async (e) => {
  if (e.target.dataset.haColor || e.target.dataset.haEffect) {
    const field = e.target;
    field.disabled = true;
    try {
      await api(
        "/api/ha/action",
        "POST",
        field.dataset.haColor
          ? {
              entity: field.dataset.haColor,
              action: "color",
              color: field.value,
            }
          : {
              entity: field.dataset.haEffect,
              action: "effect",
              effect: field.value,
            },
      );
      toast("Light updated");
      await refreshPage("home");
    } catch (err) {
      toast(err.message, true);
    } finally {
      field.disabled = false;
    }
    return;
  }
  if (e.target.dataset.haSelect || e.target.dataset.haNumber) {
    const node = e.target;
    node.disabled = true;
    try {
      const isSelect = Boolean(node.dataset.haSelect);
      await api(
        "/api/ha/action",
        "POST",
        isSelect
          ? {
              entity: node.dataset.haSelect,
              action: "select_option",
              option: node.value,
            }
          : {
              entity: node.dataset.haNumber,
              action: "set_value",
              value: Number(node.value),
            },
      );
      toast("Control updated");
      refreshPage("home");
    } catch (err) {
      toast(err.message, true);
      node.disabled = false;
    }
    return;
  }
  if (!e.target.dataset.control) return;
  const input = e.target;
  input.disabled = true;
  const action = input.dataset.control;
  try {
    await api("/api/ha/action", "POST", {
      entity: input.dataset.entityId,
      action,
      [action === "color_temp"
        ? "kelvin"
        : action === "brightness"
          ? "brightness"
          : "percentage"]: Number(input.value),
    });
    toast("Setting updated");
    refreshPage("home");
  } catch (err) {
    toast(err.message, true);
  } finally {
    input.disabled = false;
  }
});

function keyboardTiles() {
  if (state.page === "home")
    return [...document.querySelectorAll(".home-tile .tile-open")];
  if (state.page === "apps") return [...document.querySelectorAll(".app-card")];
  if (state.page === "media")
    return [...document.querySelectorAll(".media-shortcut")];
  return [...document.querySelectorAll(".metric")];
}
function keyboardNavigate(key) {
  const tiles = keyboardTiles();
  if (!tiles.length) return false;
  const current = tiles.includes(document.activeElement)
    ? document.activeElement
    : null;
  if (!current) {
    tiles[0].focus();
    state.keyboardMode = true;
    state.keyboardTarget = tiles[0].dataset.device || tiles[0].href || "";
    return true;
  }
  const origin = current.getBoundingClientRect();
  const x = origin.left + origin.width / 2,
    y = origin.top + origin.height / 2;
  const horizontal = key === "h" || key === "l",
    sign = key === "h" || key === "k" ? -1 : 1;
  const candidates = tiles
    .filter((tile) => tile !== current)
    .map((tile) => {
      const bounds = tile.getBoundingClientRect();
      const dx = bounds.left + bounds.width / 2 - x,
        dy = bounds.top + bounds.height / 2 - y;
      const forward = horizontal ? sign * dx : sign * dy;
      const offset = Math.abs(horizontal ? dy : dx);
      return { tile, forward, score: forward + offset * 2 };
    })
    .filter((entry) => entry.forward > 12)
    .sort((a, b) => a.score - b.score);
  const next = candidates[0]?.tile;
  if (!next) return true;
  next.focus({ preventScroll: false });
  state.keyboardMode = true;
  state.keyboardTarget = next.dataset.device || next.href || "";
  return true;
}
function commandSearch() {
  state.quick = false;
  state.device = null;
  state.roomPicker = false;
  state.help = false;
  render();
  root.insertAdjacentHTML("beforeend", searchSheet());
  document.getElementById("command-input")?.focus();
  renderResults("");
}
function desktopKeyboard() {
  return window.matchMedia("(min-width: 900px) and (pointer: fine)").matches;
}
document.addEventListener("keydown", (e) => {
  if (!state.me || e.defaultPrevented) return;
  const key = e.key.toLowerCase();
  if ((e.metaKey || e.ctrlKey) && key === "k") {
    e.preventDefault();
    commandSearch();
    return;
  }
  if (e.key === "Escape") {
    if (document.querySelector(".overlay")) {
      e.preventDefault();
      state.quick = false;
      state.roomPicker = false;
      state.device = null;
      state.help = false;
      render();
    } else if (desktopKeyboard()) {
      document.activeElement?.blur?.();
      state.keyboardTarget = "";
    }
    return;
  }
  const typing = e.target.matches(
    'input,textarea,select,[contenteditable="true"]',
  );
  if (typing || e.metaKey || e.ctrlKey || e.altKey || !desktopKeyboard())
    return;
  if (key === "?") {
    e.preventDefault();
    state.help = !state.help;
    state.device = null;
    state.quick = false;
    state.roomPicker = false;
    render();
    return;
  }
  if (document.querySelector(".overlay")) {
    if (state.device && ["h", "j", "k", "l"].includes(key)) {
      const items = [
        ...document.querySelectorAll(
          ".device-sheet button:not([disabled]),.device-sheet select:not([disabled]),.device-sheet input:not([disabled])",
        ),
      ];
      const ix = items.indexOf(document.activeElement);
      const change = ["h", "k"].includes(key) ? -1 : 1;
      const next = Math.max(
        0,
        Math.min(items.length - 1, ix < 0 ? 0 : ix + change),
      );
      items[next]?.focus();
      e.preventDefault();
    }
    if (
      key === "enter" &&
      document.activeElement?.matches(
        ".device-sheet button:not([disabled]),.shortcut-sheet button",
      )
    ) {
      e.preventDefault();
      document.activeElement.click();
    }
    return;
  }
  const pages = ["overview", "home", "media", "apps"];
  if (/^[1-4]$/.test(key)) {
    const page = pages[Number(key) - 1];
    if (has(page)) {
      e.preventDefault();
      move(page);
    }
    return;
  }
  if (["h", "j", "k", "l"].includes(key)) {
    if (keyboardNavigate(key)) e.preventDefault();
    return;
  }
  if (key === "/") {
    e.preventDefault();
    const field = document.getElementById(
      state.page === "home"
        ? "home-search"
        : state.page === "apps"
          ? "app-search"
          : "command-input",
    );
    if (field) field.focus();
    else commandSearch();
    return;
  }
  if (
    key === "enter" &&
    state.keyboardMode &&
    document.activeElement?.matches(
      ".home-tile .tile-open, .app-card, .metric, .media-shortcut",
    )
  ) {
    e.preventDefault();
    document.activeElement.click();
    return;
  }
  if (key === "r") {
    e.preventDefault();
    refreshPage(state.page);
    return;
  }
  if (key === "t" && state.page === "home") {
    const tile = document.activeElement?.closest(".home-tile");
    const power = tile?.querySelector(".tile-power:not(:disabled)");
    if (power) {
      e.preventDefault();
      power.click();
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
    ["overview", "home", "media"].includes(state.page)
  )
    refreshPage(state.page);
}, 20000);
init();
