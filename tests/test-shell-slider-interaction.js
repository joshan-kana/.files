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
    /interaction\.pressed \? 0\.26 : root\.thumbHovered \? 0\.5 : 0\.42/,
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
  assert.match(slider, /onCanceled: root\.interactionFinished\(root\.value\)/);
  assert.doesNotMatch(slider, /Keys\.onReleased|onClicked:/);
});
