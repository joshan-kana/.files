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
    /thumbPressed: motion\.enabled && \(interaction\.pressed \|\| motion\.keyboardSlider === root\)/,
  );
  assert.match(
    slider,
    /displayedValue: interaction\.pressed \? fractionForX\(interaction\.mouseX\) : normalizedValue/,
  );
  assert.match(
    slider,
    /function beginKeyboardAdjustment\(\): void \{[\s\S]*?motion\.beginKeyboardAdjustment\(root\)/,
  );
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  assert.match(
    qml("SystemContent.qml"),
    /brightnessSlider\.beginKeyboardAdjustment\(\);\s*brightness\.adjust\(direction \* 5\)/,
  );
  assert.match(
    qml("SystemContent.qml"),
    /mediaCard\.triggerTransport\("forward", event\.isAutoRepeat\)/,
  );
  assert.match(
    qml("MediaContent.qml"),
    /progressTrack\.beginKeyboardAdjustment\(\);\s*fullTransport\.triggerAction\("back", event\.isAutoRepeat\)/,
  );
  assert.match(
    qml("MediaContent.qml"),
    /onInteractionCanceled: content\.scrubbing = false/,
  );
});

test("every shared slider smooths external changes and holds feedback until real key release", () => {
  assert.match(slider, /property bool animateValueChanges: true/);
  assert.match(slider, /SmoothedAnimation \{/);
  assert.match(
    slider,
    /enabled: root\.animateValueChanges && root\.motion\.enabled && !interaction\.pressed/,
  );
  assert.doesNotMatch(slider, /keyboardPulse|Timer \{/);
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  const motion = qml("Motion.qml");
  assert.match(
    motion,
    /function releaseAdjustmentKey[\s\S]*?key !== adjustmentKey/,
  );
  for (const name of ["SystemContent.qml", "MediaContent.qml"]) {
    const source = qml(name);
    assert.match(
      source,
      /Keys\.onReleased: event => \{[\s\S]*?!event\.isAutoRepeat && (?:root|content)\.motion\.releaseAdjustmentKey\(event\.key\)/,
    );
    assert.match(
      source,
      /Keys\.onPressed: event => \{[\s\S]*?motion\.noteKeyDown\(event\.key\)/,
    );
    assert.match(
      source,
      /onActiveFocusChanged: if \(!activeFocus\)\s+(?:root|content)\.motion\.endKeyboardAdjustment/,
    );
  }
});
