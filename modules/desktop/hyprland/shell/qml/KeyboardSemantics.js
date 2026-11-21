function lockState(devices, field) {
  const values = devices
    .map((device) => device[field])
    .filter((value) => typeof value === "boolean");
  if (!values.length) return "unknown";
  if (values.some((value) => value !== values[0])) return "mixed";
  return values[0] ? "on" : "off";
}

function snapshot(data) {
  if (!data || !Array.isArray(data.keyboards)) return null;
  // A compositor's main device is not necessarily an actual keyboard.
  const keyboards = data.keyboards.filter(
    (device) =>
      device &&
      device.name !== "power-button" &&
      (typeof device.capsLock === "boolean" ||
        typeof device.numLock === "boolean"),
  );
  if (!keyboards.length) return null;
  const selected = keyboards.find((device) => device.main) || keyboards[0];
  const layouts = [
    ...new Set(
      keyboards
        .map((device) => device.active_keymap || device.layout)
        .filter(Boolean),
    ),
  ];
  return {
    deviceCount: keyboards.length,
    deviceName:
      keyboards.length === 1
        ? selected.name || "Keyboard"
        : `${keyboards.length} keyboards`,
    capsState: lockState(keyboards, "capsLock"),
    numState: lockState(keyboards, "numLock"),
    layoutName:
      layouts.length === 1
        ? layouts[0]
        : layouts.length > 1
          ? "Mixed layouts"
          : "Unknown",
  };
}
