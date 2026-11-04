const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const qmlDir = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const qml = (name) => fs.readFileSync(path.join(qmlDir, name), "utf8");

test("window and glass opacity persist independently from 20% to 100%", () => {
  const prefs = qml("AppearancePreferences.qml");
  for (const [setting, defaultValue] of [
    ["windowOpacity", "0.82"],
    ["glassOpacity", "0.70"],
  ]) {
    assert.match(
      prefs,
      new RegExp(
        "property real " + setting + ": " + defaultValue.replace(".", "\\."),
      ),
    );
    assert.match(
      prefs,
      new RegExp(
        setting +
          ": Math\\.max\\(0\\.20, Math\\.min\\(1, saved\\." +
          setting +
          "\\)\\)",
      ),
    );
    assert.match(
      prefs,
      new RegExp('saved\\.setValue\\("' + setting + '", next\\)'),
    );
    assert.match(
      prefs,
      new RegExp("Math\\.max\\(0\\.20, Math\\.min\\(1, value\\)\\)"),
    );
  }
  assert.match(prefs, /saved\.sync\(\)/);
  assert.match(
    prefs,
    /const opacity = \(windowTransparencyEnabled \? windowOpacity : 1\)\.toFixed\(2\)/,
  );
  assert.match(
    prefs,
    /active_opacity = " \+ opacity \+ ", inactive_opacity = " \+ opacity/,
  );
  assert.match(prefs, /interval: 65/);
  assert.match(prefs, /windowOpacityApply\.restart\(\)/);
  assert.match(prefs, /if \(!wasEnabled\)\s*applyShellGlass\(\)/);
});

test("frosted-glass percentage maps directly to actual pane alpha", () => {
  const root = qml("shell.qml");
  const theme = qml("Theme.qml");
  const surface = qml("ShellSurface.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(root, /glassOpacity: appearance\.glassOpacity/);
  assert.match(theme, /property real glassOpacity: 0\.70/);
  assert.match(
    surface,
    /fillOpacity: frameConnected \? 0 : !glassAllowed \|\| !theme\.shellGlassEnabled \|\| surfaceLayer === ShellSurface\.Background \? 1 : theme\.glassOpacity/,
  );
  assert.doesNotMatch(surface, /theme\.glassOpacity \* \(/);
  assert.match(
    frame,
    /reactiveFrameMotionColor\(0\.5, output\.reactiveActive\)/,
  );
  assert.match(theme, /shellGlassEnabled \? glassOpacity : 1/);
});

test("opacity sliders live in visual-mode tiles with normal keyhints, not a separate menu", () => {
  const setting = qml("OpacitySetting.qml");
  const controls = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(setting, /ShellSurface \{/);
  assert.match(setting, /StateLayer \{/);
  assert.match(setting, /ShellSlider \{/);
  assert.match(setting, /KeyHint \{/);
  assert.match(setting, /shortcut: setting\.shortcut/);
  assert.match(setting, /from: 0\.20/);
  assert.match(setting, /to: 1/);
  assert.match(setting, /value: setting\.opacityValue/);
  assert.match(
    setting,
    /Math\.round\(setting\.opacityValue \* 100\) \+ "% opacity"/,
  );
  assert.match(
    setting,
    /onValueRequested: next => setting\.opacityRequested\(next\)/,
  );
  assert.match(setting, /onActivated: setting\.toggleRequested\(\)/);
  assert.match(
    controls,
    /OpacitySetting \{[\s\S]*?label: "Windows"[\s\S]*?onOpacityRequested: value => root\.appearance\.setWindowOpacity\(value\)/,
  );
  assert.match(
    controls,
    /OpacitySetting \{[\s\S]*?label: "Frosted glass"[\s\S]*?onOpacityRequested: value => root\.appearance\.setGlassOpacity\(value\)/,
  );
  assert.match(controls, /shortcut: "SHIFT\+D"/);
  assert.match(controls, /shortcut: "SHIFT\+R"/);
  assert.doesNotMatch(
    controls,
    /id: transparencyPanel|openTransparency|opacitySettingsButton|SHIFT\+O/,
  );
  assert.doesNotMatch(host, /systemContent\.transparencyOpen/);
  assert.equal(
    fs.existsSync(path.join(qmlDir, "TransparencyPanel.qml")),
    false,
  );
});

test("bounds are inclusive and the displayed percentage is opacity, not transparency", () => {
  const clamp = (value) =>
    Math.round(Math.max(0.2, Math.min(1, value)) * 100) / 100;
  for (const [value, expected] of [
    [-10, 0.2],
    [0, 0.2],
    [0.2, 0.2],
    [0.7, 0.7],
    [1, 1],
    [3, 1],
  ])
    assert.equal(clamp(value), expected);
  const qmlSource = qml("OpacitySetting.qml");
  assert.doesNotMatch(qmlSource, /1 - setting\.opacityValue/);
});
