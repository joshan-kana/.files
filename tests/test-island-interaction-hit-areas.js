const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("the connected frame keeps a one-pixel edge with glass-appropriate contrast", () => {
  const theme = qml("Theme.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(
    theme,
    /glassContourBorder: Qt\.rgba\(textStrong\.r, textStrong\.g, textStrong\.b/,
  );
  assert.match(
    frame,
    /theme\.shellGlassEnabled \? theme\.glassContourBorder\.a : theme\.subtleBorder\.a/,
  );
  assert.match(frame, /strokeWidth: frame\.theme\.borderThin/);
  assert.doesNotMatch(frame, /strokeWidth:.*musicReactive/);
});

test("workspace pointer feedback belongs to each workspace cell", () => {
  const bar = qml("AmbientBar.qml");
  assert.match(
    bar,
    /delegate: Item \{\s+id: workspace[\s\S]*?StateLayer \{[\s\S]*?Accessible\.name: "Switch to workspace " \+ workspace\.number[\s\S]*?onActivated: Hyprland\.dispatch/,
  );
  assert.doesNotMatch(bar, /id: workspaceHover/);
  assert.doesNotMatch(bar, /workspacePressed/);
  assert.match(
    bar,
    /hovered: item === workspaceIsland \|\| item === mediaIsland \? false/,
  );
  assert.match(
    bar,
    /pressed: item === workspaceIsland \|\| item === mediaIsland \? false/,
  );
});

test("the media island has separate visual feedback for main and playback targets", () => {
  const bar = qml("NowPlayingIsland.qml");
  assert.match(
    bar,
    /right: playbackZone\.left[\s\S]*?manualHover: mainHitArea\.containsMouse[\s\S]*?manualPress: mainHitArea\.pressed/,
  );
  assert.match(
    bar,
    /id: playbackZone[\s\S]*?manualHover: playbackHitArea\.containsMouse[\s\S]*?manualPress: playbackHitArea\.pressed/,
  );
  assert.match(
    bar,
    /id: playbackHitArea[\s\S]*?onClicked: island\.media\.togglePlaying\(\)/,
  );
  assert.match(bar, /id: mainHitArea[\s\S]*?onClicked: island\.activated\(\)/);
  assert.doesNotMatch(bar, /manualHover: island\.frameHover/);
  assert.doesNotMatch(bar, /readonly property bool frameHover:/);
});

test("a bar island with one action still forwards its shared contour state", () => {
  const bar = qml("AmbientBar.qml");
  assert.match(
    bar,
    /SystemIsland \{\s+id: systemIsland\s+onFrameHoverChanged: Qt\.callLater\(bar\.publishOrigins\)\s+onFramePressedChanged: bar\.publishOrigins\(\)/,
  );
  assert.match(qml("SystemIsland.qml"), /onActivated: island\.activated\(\)/);
});
