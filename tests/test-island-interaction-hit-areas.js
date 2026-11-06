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
  assert.match(bar, /interactionGroup: "media"/);
  assert.doesNotMatch(bar, /\.flatMap\(/);
  assert.match(bar, /islands\.push\(/);
  assert.match(bar, /hovered: item.mainHover,\s+pressed: item.mainPressed/);
  assert.match(
    bar,
    /hovered: item.playbackHover,\s+pressed: item.playbackPressed/,
  );
  assert.match(bar, /pressed: item === workspaceIsland \? false/);
});

test("media click zones share one clipped contour in detached mode", () => {
  const media = qml("NowPlayingIsland.qml");
  assert.match(media, /id: mainHighlight[\s\S]*?clip: true/);
  assert.match(media, /id: playbackHighlight[\s\S]*?clip: true/);
  assert.match(media, /x: -mainHighlight\.width/);
  assert.match(
    media,
    /fillOpacity: island\.frameConnected \? 0 : island\.mainPressed/,
  );
  assert.match(
    media,
    /fillOpacity: island\.frameConnected \? 0 : island\.playbackPressed/,
  );
  assert.match(media, /leftMargin: island\.theme\.spacing2/);
  assert.match(
    media,
    /id: playbackHitArea[\s\S]*?onClicked: island\.media\.togglePlaying\(\)/,
  );
  assert.match(
    media,
    /id: mainHitArea[\s\S]*?onClicked: island\.activated\(\)/,
  );
  assert.doesNotMatch(media, /manualHover: mainHitArea\.containsMouse/);
  assert.doesNotMatch(media, /manualHover: playbackHitArea\.containsMouse/);
});

test("a bar island with one action still forwards its shared contour state", () => {
  const bar = qml("AmbientBar.qml");
  assert.match(
    bar,
    /SystemIsland \{\s+id: systemIsland[\s\S]*?onFrameHoverChanged: Qt\.callLater\(bar\.publishOrigins\)\s+onFramePressedChanged: bar\.publishOrigins\(\)/,
  );
  assert.match(qml("SystemIsland.qml"), /onActivated: island\.activated\(\)/);
});
