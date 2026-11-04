const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const read = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("wallpaper apply target uses the shared persisted appearance owner", () => {
  const appearance = read("AppearancePreferences.qml");
  assert.match(appearance, /property string wallpaperTargetOutput: ""/);
  assert.match(
    appearance,
    /readonly property string wallpaperTargetOutput: saved\.wallpaperTargetOutput/,
  );
  assert.match(appearance, /wallpaperTargetOutput: "",/);
  assert.match(
    appearance,
    /function setWallpaperTargetOutput\(output: string\): void/,
  );
  assert.match(
    appearance,
    /saved\.setValue\("wallpaperTargetOutput", output\)/,
  );
  assert.match(appearance, /saved\.sync\(\)/);
});

test("reopening gallery retains specific monitor and all-display selections", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(
    gallery,
    /outputName: appearance\.wallpaperTargetOutput\.length > 0 \? appearance\.wallpaperTargetOutput : hostOutput/,
  );
  assert.match(gallery, /function openView\(\): void \{\s*open = true;/);
  assert.doesNotMatch(gallery, /selectedOutput = hostOutput/);
  assert.match(
    gallery,
    /appearance\.setWallpaperTargetOutput\(outputChoices\[\(index \+ 1\) % outputChoices\.length\]\)/,
  );
  assert.match(gallery, /\["all"\]/);
  assert.match(gallery, /outputLabel: outputName === "all" \? "All displays"/);
});

test("saved monitor identity is not silently redirected when output disconnects", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(
    gallery,
    /outputAvailable: outputName === "all" \|\| outputChoices\.includes\(outputName\)/,
  );
  assert.match(
    gallery,
    /outputName \+ \(outputAvailable \? "" : " \(disconnected\)"\)/,
  );
  assert.match(gallery, /!outputAvailable \|\| !selectedPath\(\)/);
  assert.match(gallery, /!outputAvailable \|\| resetProcess\.running/);
  assert.match(gallery, /!open \|\| !outputAvailable/);
});

test("wallpaper operations receive the persisted target verbatim", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(gallery, /"set", outputName, resizeMode, applyingPath/);
  assert.match(gallery, /"reset", outputName/);
  assert.match(gallery, /"current", currentRequestOutput/);
});
