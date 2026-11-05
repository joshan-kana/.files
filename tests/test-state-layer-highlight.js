const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("all detached hover and press highlights use one antialiased vector squircle rather than triangulated native fill", () => {
  const state = qml("StateLayer.qml");
  assert.match(state, /fillColor: "transparent"/);
  assert.match(state, /preferredRendererType: Shape\.CurveRenderer/);
  assert.match(state, /fillColor: root\.stateColor/);
  assert.match(state, /path: hoverSurface\.fillPathData/);
  assert.match(state, /if \(root\.visualPressed\)/);
  assert.match(state, /return root\.pressOpacity/);
  assert.match(state, /return root\.hoverOpacity/);
  assert.match(state, /showHover: true/);
  assert.match(state, /if \(!animationsEnabled \|\| !showHover\)/);
});

test("audio, network, Bluetooth, and notification feedback all use the common StateLayer", () => {
  for (const name of [
    "ShellAction.qml",
    "NetworkPanel.qml",
    "BluetoothPanel.qml",
    "NotificationCard.qml",
    "NotificationPopup.qml",
  ])
    assert.match(qml(name), /StateLayer\s*\{/);
  const popup = qml("NotificationPopup.qml");
  const frame = qml("FrameGeometry.js");
  assert.match(popup, /hovered: toast\.hovered/);
  assert.match(popup, /pressed: toast\.pointerPressed/);
  assert.match(popup, /showHover: !popup\.frameConnected/);
  assert.match(frame, /dock\.hovered \|\| dock\.pressed/);
  assert.match(frame, /dock\.pressed \? pressedPaths : hoverPaths/);
});

test("shared passive hover stays active across interactive child surfaces without stealing press events", () => {
  const state = qml("StateLayer.qml");
  assert.match(state, /HoverHandler \{/);
  assert.match(state, /pointerHovered: false/);
  assert.match(state, /if \(containsMouse \|\| hoverHandler\.hovered\)/);
  assert.match(state, /interval: 55/);
  assert.match(state, /if \(root\.pointerHovered \|\| root\.manualHover\)/);
  assert.match(state, /onClicked: event => activated\(event\)/);
  for (const name of [
    "WallpaperPanel.qml",
    "ConnectivityTile.qml",
    "QuickSettingChip.qml",
    "OpacitySetting.qml",
    "AdjustableSetting.qml",
  ])
    assert.match(qml(name), /\.pointerHovered/);
});
