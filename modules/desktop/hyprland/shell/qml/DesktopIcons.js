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
});

function glyphFor(destination) {
  return destinations[destination] || "";
}
