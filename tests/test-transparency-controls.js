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
        "property real " +
          setting +
          ": appearance\\.runtime\\.appearanceDefaults\\." +
          setting,
      ),
    );
    assert.ok(
      prefs.includes(
        setting + ': Math.max(0.20, Math.min(1, effective("' + setting + '"))',
      ),
    );
    assert.match(
      prefs,
      new RegExp('storeOverride\\("' + setting + '", next\\)'),
    );
    assert.match(prefs, /Math\.max\(0\.20, Math\.min\(1, value\)\)/);
  }
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  for (const [setting, defaultValue] of [
    ["windowOpacity", "0.82"],
    ["glassOpacity", "0.70"],
  ])
    assert.match(
      nix,
      new RegExp(
        setting +
          " = lib\\.mkOption[\\s\\S]*?default = " +
          defaultValue.replace(".", "\\."),
      ),
    );
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
  assert.match(root, /glassOpacity: qmlAppearance\.glassOpacity/);
  assert.match(theme, /property real glassOpacity: 0\.70/);
  assert.match(
    surface,
    /fillOpacity: frameConnected \? 0 : !glassAllowed \|\| !theme\.shellGlassEnabled \|\| surfaceLayer === ShellSurface\.Background \? 1 : theme\.glassOpacity/,
  );
  assert.doesNotMatch(surface, /theme\.glassOpacity \* \(/);
  assert.match(frame, /reactiveFrameColor\(0\.5\)/);
  assert.match(theme, /shellGlassEnabled \? glassOpacity : 1/);
});

test("opacity and shared blur parameters live in focused details, not compact tiles", () => {
  const detail = qml("SettingsDetail.qml");
  const controls = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  const preferences = qml("AppearancePreferences.qml");
  assert.match(detail, /ParameterCard \{/);
  assert.match(qml("ParameterCard.qml"), /ShellSlider \{/);
  for (const key of ["windowOpacity", "glassOpacity", "blurSize"])
    assert.ok(detail.includes('key: "' + key + '"'), key);
  assert.match(detail, /appearance\.setWindowOpacity\(value \/ 100\)/);
  assert.match(detail, /appearance\.setGlassOpacity\(value \/ 100\)/);
  assert.match(detail, /appearance\.setBlurSize\(value\)/);
  assert.match(detail, /appearance\.toggleBlur\(\)/);
  assert.match(preferences, /function toggleBlur\(\): void/);
  assert.match(preferences, /function clearOverride\(key: string\): void/);
  assert.doesNotMatch(controls, /OpacitySetting \{|AdjustableSetting \{/);
  assert.match(controls, /onDetailsRequested: root\.openSetting\("windows"\)/);
  assert.match(controls, /onDetailsRequested: root\.openSetting\("glass"\)/);
  assert.match(
    controls,
    /shortcut: root\.runtime\.shellHint\("SystemContent\.windowTransparency"\)/,
  );
  assert.match(
    controls,
    /shortcut: root\.runtime\.shellHint\("SystemContent\.shellGlass"\)/,
  );
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
