// Scenes contain user-selected shell modes and switches. Schedules, hardware,
// application state and other persistent preferences remain with their owners.
const appearanceKeys = [
  "wallpaperSpectrumEnabled",
  "musicReactiveEnabled",
  "windowTransparencyEnabled",
  "shellGlassEnabled",
  "frameVisible",
  "blurEnabled",
];

const optionalAppearanceKeys = [
  "atmosphereEnabled",
  "atmosphereAudioEnabled",
  "atmosphereBackdrop",
  "islandVisualizerEnabled",
  "controlsVisualizerEnabled",
  "mediaVisualizerEnabled",
];
const requiredAppearanceKeys = [...appearanceKeys];
const optionalModeKeys = ["atmosphereMode"];
const effectKeys = ["vhs", "crt", "hologram", "glitch", "film", "monochrome"];
appearanceKeys.push(
  ...optionalAppearanceKeys,
  ...optionalModeKeys,
  "screenEffectsEnabled",
);

function validProfile(profile) {
  return !!(
    profile &&
    typeof profile.name === "string" &&
    profile.name.trim() === profile.name &&
    profile.name.length > 0 &&
    profile.name.length <= 40 &&
    profile.appearance &&
    requiredAppearanceKeys.every(
      (key) => typeof profile.appearance[key] === "boolean",
    ) &&
    optionalAppearanceKeys.every(
      (key) =>
        !(key in profile.appearance) ||
        typeof profile.appearance[key] === "boolean",
    ) &&
    optionalModeKeys.every(
      (key) =>
        !(key in profile.appearance) ||
        typeof profile.appearance[key] === "string",
    ) &&
    (profile.appearance.screenEffectsEnabled === undefined ||
      (profile.appearance.screenEffectsEnabled !== null &&
        effectKeys.every(
          (key) =>
            typeof profile.appearance.screenEffectsEnabled[key] === "boolean",
        ) &&
        Object.keys(profile.appearance.screenEffectsEnabled).every((key) =>
          effectKeys.includes(key),
        ))) &&
    typeof profile.animations === "boolean" &&
    typeof profile.silent === "boolean" &&
    typeof profile.presentation === "boolean"
  );
}

function cleanProfiles(items) {
  if (!Array.isArray(items)) return [];
  const names = new Set();
  return items
    .filter((profile) => {
      if (!validProfile(profile) || names.has(profile.name)) return false;
      names.add(profile.name);
      return true;
    })
    .slice(0, 12);
}

function appearanceValues(profile) {
  const values = {};
  for (const key of [...requiredAppearanceKeys, ...optionalAppearanceKeys])
    if (typeof profile.appearance[key] === "boolean")
      values[key] = profile.appearance[key];
  for (const key of optionalModeKeys)
    if (typeof profile.appearance[key] === "string")
      values[key] = profile.appearance[key];
  if (profile.appearance.screenEffectsEnabled)
    values.screenEffectsEnabled = profile.appearance.screenEffectsEnabled;
  return values;
}
