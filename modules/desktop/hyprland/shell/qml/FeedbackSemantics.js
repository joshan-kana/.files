// Shared presentation vocabulary for observed device states and adjustments.
function symbol(kind, muted, value, state) {
  if (kind === "keyboard")
    return state === "on" ? "󰪛" : state === "off" ? "󰪜" : "󰀨";
  if (kind === "microphone") return muted ? "󰍭" : value > 0 ? "󰍬" : "󰍭";
  if (kind === "volume") return muted ? "󰖁" : value < 34 ? "󰕿" : "󰕾";
  if (kind === "brightness") return "󰃟";
  if (kind === "mode") return "󰍉";
  if (kind === "resize") return "󰩨";
  if (kind === "recording") return "󰑋";
  return "󰋽";
}

function stateLabel(state) {
  return state === "on"
    ? "ON"
    : state === "off"
      ? "OFF"
      : state === "mixed"
        ? "MIXED"
        : "UNKNOWN";
}
