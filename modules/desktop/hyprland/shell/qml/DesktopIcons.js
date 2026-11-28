// A destination keeps one visual identity across Controls, detail panels,
// and the command palette. Dynamic state icons (Wi-Fi, Bluetooth, warnings)
// belong to their state owner, not this destination vocabulary.
const destinations = Object.freeze({
  theme: "󰏘",
  wallpaper: "󰸉",
  session: "󰐥",
  scenes: "󰐩",
  resources: "󰍛",
  captures: "󰕧",
  clipboard: "󰅌",
  shortcuts: "󰌌",
  audioMixer: "♫",
  displays: "󰍹",
  windows: "󰍹",
  glass: "󰊠",
  vhs: "󰨛",
  bar: "󰀻",
  spectrum: "\u{F147D}",
  status: "󰋽",
});

function glyphFor(destination) {
  return destinations[destination] || "";
}

// Shared state glyphs for both the compact capability and its expanded view.
function capabilityGlyph(kind, state) {
  switch (kind) {
    case "reactive":
      return glyphFor("audioMixer");
    case "network":
      return state.wifiConnected ? "󰤨" : state.networkConnected ? "󰈀" : "󰤭";
    case "bluetooth":
      return state.active ? "󰂯" : "󰂲";
    case "alerts":
      return state.active ? "󰂚" : "󰂛";
    case "stay":
      return state.active ? "󰅶" : "󰒲";
    case "power":
      return state.batteryAvailable
        ? state.batteryLevelIcon
        : glyphFor("session");
    case "frame":
      return state.active ? "󰏗" : "󰏖";
    case "motion":
      return state.active ? "󰐊" : "󰏤";
    case "nightLight":
      return state.active ? "󰖔" : "󰖙";
    default:
      return glyphFor(kind);
  }
}

// The glyph is the current state; the adjacent verb describes the action.
function toggleGlyph(active) {
  return active ? "󰔡" : "󰔢";
}

function actionGlyph(action) {
  return (
    {
      reset: "󰁯",
      revert: "󰕌",
      refresh: "󰑐",
      confirm: "󰄬",
      cancel: "󰜺",
      decrease: "󰍴",
      increase: "󰐕",
      copy: "󰆏",
      edit: "󰏫",
      expand: "󰅀",
      collapse: "󰅃",
      settings: "󰒓",
      save: "󰆓",
      delete: "󰆴",
    }[action] || ""
  );
}

function powerProfileGlyph(profile) {
  return (
    {
      "power-saver": "󰌪",
      balanced: "󰾅",
      performance: "󰓅",
    }[profile] || glyphFor("session")
  );
}

function spectrumGlyph(mode) {
  return mode === "off" ? "󰝟" : mode === "curve" ? "\u{F012A}" : "\u{F0128}";
}

// Atmosphere glyphs are shared between the dashboard tile and its detail.
function effectGlyph(mode) {
  return (
    {
      aurora: "󰖜",
      liquid: "󰖌",
      nebula: "󰫢",
      ripples: "󰉺",
      geometry: "󰛡",
      flow: "󰖝",
      prism: "󰕯",
    }[mode] || glyphFor("wallpaper")
  );
}
