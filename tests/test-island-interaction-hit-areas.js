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
    /StateLayer \{\s+id: playbackHitArea[\s\S]*?showHover: false[\s\S]*?onActivated: island\.media\.togglePlaying\(\)/,
  );
  assert.match(
    media,
    /StateLayer \{\s+id: mainHitArea[\s\S]*?showHover: false[\s\S]*?onActivated: island\.activated\(\)/,
  );
  assert.match(
    media,
    /readonly property bool mainHover: mainHitArea.pointerHovered && !playbackHitArea.pointerHovered/,
  );
  assert.match(
    media,
    /readonly property bool playbackHover: playbackHitArea.pointerHovered && media.canTogglePlaying/,
  );
  assert.match(
    media,
    /readonly property bool mainPressed: mainHitArea.visualPressed/,
  );
  assert.match(
    media,
    /readonly property bool playbackPressed: playbackHitArea.visualPressed/,
  );
  assert.doesNotMatch(media, /MouseArea \{/);
  assert.doesNotMatch(media, /manualHover: mainHitArea\.containsMouse/);
  assert.doesNotMatch(media, /manualHover: playbackHitArea\.containsMouse/);
});

test("a bar island with one action still forwards its shared contour state", () => {
  const bar = qml("AmbientBar.qml");
  assert.match(
    bar,
    /SystemIsland \{\s+id: systemIsland[\s\S]*?onFrameHoverChanged: Qt\.callLater\(bar\.publishOrigins\)\s+onFramePressedChanged: bar\.publishOrigins\(\)/,
  );
  const status = qml("SystemIsland.qml");
  assert.match(status, /acceptedButtons: Qt\.LeftButton \| Qt\.RightButton/);
  assert.match(
    status,
    /if \(event\.button === Qt\.RightButton\)\s*island\.inspectRequested\(\)/,
  );
  assert.match(status, /else\s*island\.activated\(\)/);
});

test("occluded islands fade with continuous frame contour and no clickable ghost", () => {
  const bar = qml("AmbientBar.qml");
  const media = qml("NowPlayingIsland.qml");
  assert.match(bar, /item.opacity > 0.01/);
  assert.match(bar, /height: item.height \* item.opacity/);
  assert.match(bar, /enabled: !bar.workspaceOccluded/);
  assert.match(bar, /enabled: !bar.notificationOccluded/);
  assert.match(bar, /enabled: !bar.recordingOccluded/);
  assert.match(bar, /enabled: !bar.systemOccluded/);
  assert.match(
    bar,
    /onOpacityChanged: if \(bars.frameVisible\)\s+Qt.callLater\(bar.publishOrigins\)/,
  );
  assert.match(media, /enabled: !occluded/);
  assert.match(media, /duration: island.motion.effectsNormal/);
});

test("workspace selection remains clipped during animated count changes", () => {
  const bar = qml("AmbientBar.qml");
  assert.match(bar, /id: workspaceIsland[\s\S]*?Behavior on width/);
  assert.match(
    bar,
    /width: Math.max\(bar.workspaceCellWidth, Math.min\(implicitWidth, workspaceIsland.width/,
  );
  assert.match(bar, /id: workspaceTrack[\s\S]*?clip: true/);
  assert.match(
    bar,
    /selectionPosition = ids.indexOf\(focused\) \* \(bar.workspaceCellWidth \+ bar.workspaceCellGap\)/,
  );
  assert.match(
    bar,
    /x: Math.max\(0, Math.min\(workspaceTrack.selectionPosition, workspaceTrack.width - bar.workspaceCellWidth\)\)/,
  );
});

test("connected island hover publication follows actual shared hover state", () => {
  const bar = qml("AmbientBar.qml");
  const layer = qml("StateLayer.qml");
  assert.match(
    bar,
    /id: clockPress[\s\S]*?onPointerHoveredChanged: Qt.callLater\(bar.publishOrigins\)/,
  );
  assert.match(
    bar,
    /id: notificationPress[\s\S]*?onPointerHoveredChanged: Qt.callLater\(bar.publishOrigins\)/,
  );
  assert.match(
    bar,
    /id: clockIsland[\s\S]*?onOpacityChanged: if \(bars.frameVisible\)/,
  );
  assert.match(bar, /y: y \+ item.height \* \(1 - item.opacity\) \/ 2/);
  assert.match(layer, /onVisibleChanged: updatePointerHover\(\)/);
  assert.match(layer, /if \(!visible \|\| !enabled\)/);
});

test("connected hover follows delayed pointer state rather than raw enter events", () => {
  const bar = qml("AmbientBar.qml");
  const layer = qml("StateLayer.qml");
  for (const id of ["clockPress", "notificationPress"]) {
    const start = bar.indexOf("id: " + id);
    const end = bar.indexOf("onActivated:", start);
    const snippet = bar.slice(start, end);
    assert.ok(start >= 0 && end > start, id);
    assert.match(
      snippet,
      /onPointerHoveredChanged: Qt\.callLater\(bar\.publishOrigins\)/,
    );
    assert.match(snippet, /onVisualPressedChanged: bar\.publishOrigins\(\)/);
    assert.doesNotMatch(
      snippet,
      /onContainsMouseChanged: Qt\.callLater\(bar\.publishOrigins\)/,
    );
  }
  assert.match(layer, /onVisibleChanged: updatePointerHover\(\)/);
  assert.match(layer, /if \(!visible \|\| !enabled\)/);
  assert.match(
    layer,
    /root\.visible && root\.enabled && \(root\.containsMouse \|\| hoverHandler\.hovered\)/,
  );
});

test("center clock restoration publishes its opacity to frame contour", () => {
  const bar = qml("AmbientBar.qml");
  const source = bar.slice(
    bar.indexOf("id: clockIsland"),
    bar.indexOf("id: notificationIsland"),
  );
  assert.match(
    source,
    /onOpacityChanged: if \(bars\.frameVisible\)\s+Qt\.callLater\(bar\.publishOrigins\)/,
  );
  assert.match(
    source,
    /visible: bars\.clockReveal > 0\.001\s+opacity: bars\.clockReveal/,
  );
  assert.match(bar, /item\.opacity > 0\.01/);
  assert.match(bar, /y: y \+ item\.height \* \(1 - item\.opacity\) \/ 2/);
});
