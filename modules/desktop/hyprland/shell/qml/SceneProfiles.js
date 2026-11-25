// Scenes contain only user-selected shell switches. Schedules, hardware,
// application state and other persistent preferences remain with their owners.
const appearanceKeys = [
  "wallpaperSpectrumEnabled",
  "musicReactiveEnabled",
  "windowTransparencyEnabled",
  "shellGlassEnabled",
  "vhsEnabled",
  "frameVisible",
  "blurEnabled",
];

function validProfile(profile) {
  return !!(
    profile &&
    typeof profile.name === "string" &&
    profile.name.trim() === profile.name &&
    profile.name.length > 0 &&
    profile.name.length <= 40 &&
    profile.appearance &&
    appearanceKeys.every(
      (key) => typeof profile.appearance[key] === "boolean",
    ) &&
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
  for (const key of appearanceKeys) values[key] = profile.appearance[key];
  return values;
}
