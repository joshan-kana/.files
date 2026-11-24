const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const slider = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/qml/ShellSlider.qml"),
  "utf8",
);

test("slider morphs into a narrow pressed thumb without moving the value centre", () => {
  assert.match(
    slider,
    /thumbCenterX: handleSize \/ 2 \+ displayedValue \* Math\.max\(1, width - handleSize\)/,
  );
  assert.match(
    slider,
    /root\.thumbPressed \? 0\.26 : root\.motion\.enabled && root\.thumbHovered \? 0\.5 : 0\.42/,
  );
  assert.match(slider, /x: root\.thumbCenterX - width \/ 2/);
  assert.match(slider, /motion: root\.motion\s+type: Anim\.FastSpatial/);
});

test("slider keeps a transparent thumb gap and press-time value dispatch", () => {
  assert.match(slider, /id: activeTrack/);
  assert.match(slider, /id: inactiveTrack/);
  assert.match(slider, /root\.thumbCenterX - root\.thumbTrackGap/);
  assert.match(slider, /root\.thumbCenterX \+ root\.thumbTrackGap/);
  assert.match(
    slider,
    /onPressed: event => \{[\s\S]*?root\.interactionStarted\(next\);\s*root\.valueRequested\(next\);/,
  );
  assert.match(
    slider,
    /onPositionChanged: event => \{[\s\S]*?root\.interactionUpdated\(next\);/,
  );
  assert.match(slider, /onCanceled: root\.interactionCanceled\(\)/);
  assert.doesNotMatch(slider, /Keys\.onReleased|onClicked:/);
});

test("direct keyboard adjustments and drag previews use the same expressive thumb without delaying state writes", () => {
  assert.match(
    slider,
    /thumbPressed: motion\.enabled && \(interaction\.pressed \|\| keyboardPulse\.running\)/,
  );
  assert.match(
    slider,
    /displayedValue: interaction\.pressed \? fractionForX\(interaction\.mouseX\) : normalizedValue/,
  );
  assert.match(
    slider,
    /function pulseAdjustment\(\): void \{[\s\S]*?keyboardPulse\.restart\(\)/,
  );
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  assert.match(
    qml("SystemContent.qml"),
    /brightnessSlider\.pulseAdjustment\(\);\s*brightness\.adjust\(direction \* 5\)/,
  );
  assert.match(
    qml("SystemContent.qml"),
    /mediaCard\.pulseSeekAdjustment\(\);\s*root\.media\.seekStep\(1\)/,
  );
  assert.match(
    qml("MediaContent.qml"),
    /progressTrack\.pulseAdjustment\(\);\s*content\.media\.seekStep\(-1\)/,
  );
  assert.match(
    qml("MediaContent.qml"),
    /onInteractionCanceled: content\.scrubbing = false/,
  );
});
