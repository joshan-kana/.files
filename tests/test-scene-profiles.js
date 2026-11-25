const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const f = vm.runInNewContext(
  read("SceneProfiles.js") +
    "\n({ appearanceKeys, validProfile, cleanProfiles, appearanceValues })",
);

function profile(name = "Focus") {
  return {
    name,
    appearance: Object.fromEntries(f.appearanceKeys.map((key) => [key, false])),
    animations: false,
    silent: true,
    presentation: false,
  };
}

test("scene snapshots preserve false values and reject invalid or duplicate definitions", () => {
  const valid = profile();
  assert.equal(f.validProfile(valid), true);
  assert.equal(f.validProfile({ ...valid, animations: null }), false);
  assert.equal(f.validProfile({ ...valid, name: " " }), false);
  assert.equal(
    f.cleanProfiles([valid, profile(), profile("Ambient")]).length,
    2,
  );
  const values = f.appearanceValues({
    ...valid,
    appearance: {
      ...valid.appearance,
      barVisible: false,
      powerProfile: "performance",
    },
  });
  assert.equal(values.wallpaperSpectrumEnabled, false);
  assert.equal("powerProfile" in values, false);
  assert.equal("barVisible" in values, false);
});

test("scene application does not persist ordinary preferences; stopping clears only temporary state", () => {
  const source = read("SceneState.qml");
  const apply = source.split("function apply(")[1].split("function stop(")[0];
  assert.doesNotMatch(apply, /preferences\.set/);
  assert.match(apply, /appearance.setSceneValues/);
  assert.match(apply, /motion.setSceneEnabled/);
  assert.match(apply, /notifications.sceneDelivery/);
  const stop = source.split("function stop(")[1].split("function remove(")[0];
  assert.match(stop, /appearance.setSceneValues\(\{\}\)/);
  assert.match(stop, /motion.setSceneEnabled\(null\)/);
  assert.match(stop, /notifications.sceneDelivery = null/);
  assert.doesNotMatch(stop, /preferences\.(set|reset)/);
  assert.match(
    read("AppearancePreferences.qml"),
    /sceneValues\[key\] : saved.value\(key\)/,
  );
  assert.match(
    read("Motion.qml"),
    /sceneEnabled === null \? qmlPreferences.value/,
  );
  assert.match(
    read("NotificationState.qml"),
    /sceneDelivery === null \? settings.value\("silent"\)/,
  );
});

test("old scenes do not override visualisers they never captured", () => {
  const old = profile();
  for (const name of [
    "islandVisualizerEnabled",
    "controlsVisualizerEnabled",
    "mediaVisualizerEnabled",
  ])
    delete old.appearance[name];
  assert.ok(f.validProfile(old));
  assert.equal("mediaVisualizerEnabled" in f.appearanceValues(old), false);
  const next = profile();
  assert.equal(f.appearanceValues(next).mediaVisualizerEnabled, false);
  next.appearance.mediaVisualizerEnabled = "off";
  assert.equal(f.validProfile(next), false);
});
