const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("mute buttons share a stable hit width across outputs, inputs, and app streams", () => {
  const quick = qml("AudioQuickSection.qml");
  const mixer = qml("AudioMixerContent.qml");
  assert.match(
    quick,
    /id: inlineMute\s+shortcut: quick\.microphone \? "X" : ""\s+width: 48/,
  );
  assert.match(mixer, /id: muteButton[\s\S]*?width: 48/);
  assert.match(quick, /inlineControl\.width[\s\S]*- inlineMute\.width/);
});

test("M remains the selected-stream command rather than a fixed output button hint", () => {
  const controls = qml("SystemContent.qml");
  const quick = qml("AudioQuickSection.qml");
  assert.match(
    controls,
    /event\.key === Qt\.Key_M[\s\S]*?root\.muteSelectedAudio\(\)/,
  );
  assert.match(quick, /shortcut: quick\.microphone \? "X" : ""/);
  assert.match(controls, /shortcut: "M",\s*label: "Mute"/);
});
