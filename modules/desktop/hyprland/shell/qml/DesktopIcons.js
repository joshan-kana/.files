// A destination keeps one visual identity across Controls, detail panels,
// and the command palette. Dynamic state icons (Wi-Fi, Bluetooth, warnings)
// belong to their state owner, not this destination vocabulary.
const destinations = Object.freeze({
  theme: "󰏘",
  wallpaper: "󰸉",
  session: "󰐥",
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
  spectrum: "󰸉",
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
