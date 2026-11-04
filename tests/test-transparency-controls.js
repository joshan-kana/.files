const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("window and glass transparency are separate persistent settings with bounded values", () => {
  const a = qml("AppearancePreferences.qml");
  assert.match(a, /property real windowOpacity: 0\.82/);
  assert.match(a, /property real glassOpacity: 0\.70/);
  assert.match(
    a,
    /windowOpacity: Math\.max\(0\.50, Math\.min\(1, saved\.windowOpacity\)\)/,
  );
  assert.match(
    a,
    /glassOpacity: Math\.max\(0\.35, Math\.min\(0\.95, saved\.glassOpacity\)\)/,
  );
  assert.match(a, /function setWindowOpacity\(value: real\): void/);
  assert.match(a, /function setGlassOpacity\(value: real\): void/);
  for (const key of ["windowOpacity", "glassOpacity"])
    assert.match(a, new RegExp('saved\\.setValue\\("' + key + '", next\\)'));
  assert.match(a, /saved\.sync\(\)/);
  assert.match(
    a,
    /const opacity = \(windowTransparencyEnabled \? windowOpacity : 1\)\.toFixed\(2\)/,
  );
  assert.match(
    a,
    /active_opacity = " \+ opacity \+ ", inactive_opacity = " \+ opacity/,
  );
  assert.match(a, /property Timer windowOpacityApply: Timer/);
  assert.match(a, /interval: 65/);
  assert.match(a, /windowOpacityApply\.restart\(\)/);
  assert.match(a, /if \(!wasEnabled\)\s*applyShellGlass\(\)/);
  assert.match(
    a,
    /if \(event\.name === "configreloaded"\) \{\s*appearance\.applyWindowTransparency\(\);\s*appearance\.applyShellGlass\(\)/,
  );
});

test("glass opacity feeds both frame and detached surfaces without modifying blur quality", () => {
  const root = qml("shell.qml");
  const theme = qml("Theme.qml");
  const surface = qml("ShellSurface.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(root, /glassOpacity: appearance\.glassOpacity/);
  assert.match(theme, /property real glassOpacity: 0\.70/);
  assert.match(surface, /theme\.glassOpacity \* \(0\.58 \/ 0\.70\)/);
  assert.match(surface, /theme\.glassOpacity \* \(0\.74 \/ 0\.70\)/);
  assert.match(
    frame,
    /frame\.theme\.reactiveFrameColor\(0\.5, output\.reactiveActive\)/,
  );
  assert.match(theme, /shellGlassEnabled \? glassOpacity : 1/);
});

test("the keyboard-first detail uses shared slider and key-hint components", () => {
  const panel = qml("TransparencyPanel.qml");
  const root = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(panel, /required property AppearancePreferences appearance/);
  assert.match(panel, /ShellSlider \{/);
  assert.match(panel, /KeyHintStrip \{/);
  assert.match(panel, /shortcut: "J\/K"/);
  assert.match(panel, /shortcut: "H\/L"/);
  assert.match(panel, /shortcut: "SPACE"/);
  assert.doesNotMatch(panel, /shortcut: "ESC"/);
  assert.match(host, /shortcut: "ESC"/);
  assert.match(panel, /function moveSelection\(steps: int\)/);
  assert.match(panel, /function adjustSelected\(steps: int\)/);
  assert.match(panel, /function toggleSelected\(\)/);
  assert.match(root, /id: transparencyPanel/);
  assert.match(root, /function openTransparency\(\): void/);
  assert.match(root, /shortcut: "SHIFT\+O"/);
  assert.match(root, /shifted && event\.key === Qt\.Key_O/);
  assert.match(root, /if \(transparencyPanel\.open\) \{/);
  assert.match(root, /transparencyPanel\.invoke\("adjustSelected", 1\)/);
  assert.match(root, /transparencyPanel\.invoke\("toggleSelected"\)/);
  assert.match(host, /systemContent\.transparencyOpen/);
});

test("lower and upper limits keep wallpaper legible while retaining useful translucency", () => {
  const clamp = (x, a, b) =>
    Math.round(Math.max(a, Math.min(b, x)) * 100) / 100;
  for (const value of [-10, 0, 0.7, 1, 3]) {
    const windows = clamp(value, 0.5, 1);
    const glass = clamp(value, 0.35, 0.95);
    assert.ok(windows >= 0.5 && windows <= 1);
    assert.ok(glass >= 0.35 && glass <= 0.95);
  }
});
