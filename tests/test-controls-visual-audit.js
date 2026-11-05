const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const base = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(base, name), "utf8");

test("nine Controls visual modes form two consistent rows at normal desktop width", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /width < 680 \? 3 : 5/);
  assert.match(controls, /const row = Math\.floor\(index \/ columns\)/);
  assert.match(
    controls,
    /const itemsInRow = Math\.min\(columns, 9 - row \* columns\)/,
  );
  assert.match(
    controls,
    /return \(width - spacing \* \(itemsInRow - 1\)\) \/ itemsInRow/,
  );
  assert.match(controls, /id: visualModeStrip/);
  assert.match(controls, /visualModeStrip\.cellWidth\(8\)/);
  assert.doesNotMatch(controls, /readonly property int columns:[^\n]*: 3\s*$/m);
});

test("night light uses inline, interactive slider with value and shared KeyHint", () => {
  const controls = read("SystemContent.qml");
  const tile = read("AdjustableSetting.qml");
  const state = read("NightLightState.qml");
  assert.match(controls, /label: "Night Light"/);
  assert.match(
    controls,
    /valueText: root\.nightLight\.supported \? root\.nightLight\.temperature/,
  );
  assert.match(
    controls,
    /onValueRequested: value => root\.nightLight\.setTemperature\(value\)/,
  );
  assert.match(tile, /ShellSlider \{/);
  assert.match(
    tile,
    /onValueRequested: next => setting\.valueRequested\(next\)/,
  );
  assert.match(tile, /KeyHint \{/);
  assert.match(tile, /keyboardSelected \? "H\/L" : setting\.toggleShortcut/);
  assert.match(state, /function setTemperature\(target: real\)/);
});

test("brightness slider is in Controls, not a draggable brightness OSD", () => {
  const controls = read("SystemContent.qml");
  const brightness = read("BrightnessState.qml");
  const osd = read("OsdPopup.qml");
  const osdState = read("OsdState.qml");
  assert.match(controls, /"No hardware backlight"/);
  assert.match(
    controls,
    /onValueRequested: next => root\.brightness\.setPercent\(next\)/,
  );
  assert.match(
    controls,
    /onInteractionStarted: root\.selectSlider\("brightness"\)/,
  );
  assert.match(brightness, /function setPercent\(target: real\)/);
  assert.match(osd, /osd\.kind === "brightness"/);
  assert.doesNotMatch(osd, /ShellSlider|MouseArea|onValueRequested/);
  assert.match(osdState, /function onPercentChanged\(\): void \{/);
  assert.match(osdState, /root\.showBrightness\(\)/);
});

test("slider keyboard workflow respects direct actions, detail Escape and global footer", () => {
  const controls = read("SystemContent.qml");
  const slider = read("ShellSlider.qml");
  const opacity = read("OpacitySetting.qml");
  assert.match(controls, /property string selectedSlider: ""/);
  assert.match(controls, /function cycleSlider\(direction: int\)/);
  assert.match(controls, /function adjustSlider\(direction: int\)/);
  assert.match(
    controls,
    /event\.key === Qt\.Key_Tab \|\| event\.key === Qt\.Key_Backtab/,
  );
  assert.match(controls, /root\.selectedSlider = ""/);
  assert.match(
    controls,
    /event\.key === Qt\.Key_Escape \|\| event\.key === Qt\.Key_Backspace/,
  );
  assert.match(controls, /shortcut: "TAB"/);
  assert.match(
    opacity,
    /shortcut: setting\.keyboardSelected \? "H\/L" : setting\.shortcut/,
  );
  assert.match(slider, /signal valueRequested\(real value\)/);
  assert.match(slider, /signal interactionStarted\(real value\)/);
});

test("hardware brightness is parsed from brightnessctl's percent field, never the raw maximum", () => {
  const brightness = read("BrightnessState.qml");
  assert.match(brightness, /fields\[4\]\.replace\("%", ""\)/);
  assert.doesNotMatch(brightness, /parseInt\(fields\[3\]/);
  assert.match(brightness, /pendingTarget = -1/);
  assert.match(brightness, /pendingDelta = 0/);
});

test("global Escape footer reflects slider-selection focus without adding widget hints", () => {
  const host = read("ShellExpansionHost.qml");
  const controls = read("SystemContent.qml");
  assert.match(host, /systemContent\.selectedSlider\.length > 0/);
  assert.match(controls, /root\.selectedSlider = ""/);
  assert.match(
    controls,
    /onSliderActivated: root\.selectSlider\("nightLight"\)/,
  );
  assert.match(host, /shortcut: "ESC"[\s\S]*?label: host\.escapeHintLabel/);
});

test("the final Visual Modes row spans the full width with four tiles, not a phantom fifth", () => {
  const controls = read("SystemContent.qml");
  const section = controls
    .split("id: visualModeStrip")[1]
    .split("ShellSurface {")[0];
  const match = section.match(
    /function cellWidth\(index: int\): real \{([\s\S]*?)\n                \}/,
  );
  assert.ok(match);
  const cellWidth = new Function(
    "index",
    "columns",
    "width",
    "spacing",
    match[1],
  );
  for (const columns of [1, 2, 3, 5]) {
    const width = 670,
      spacing = 8;
    for (let row = 0; row < Math.ceil(9 / columns); row++) {
      const first = row * columns;
      const count = Math.min(columns, 9 - first);
      const widths = Array.from({ length: count }, (_, j) =>
        cellWidth(first + j, columns, width, spacing),
      );
      assert.ok(widths.every((v) => v > 0));
      const used = widths.reduce((a, v) => a + v, 0) + (count - 1) * spacing;
      assert.ok(
        Math.abs(used - width) < 0.001,
        `row ${row} of ${columns}-column layout must fill the strip`,
      );
    }
  }
  assert.ok(cellWidth(5, 5, 670, 8) > cellWidth(0, 5, 670, 8));
});

test("reverse Backtab navigation remains owned by Controls when Night Light is selected", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /Keys.onShortcutOverride: event =>/);
  assert.match(controls, /Keys.onBacktabPressed: event =>/);
  assert.match(
    controls,
    /sliderNavigationEnabled: engaged && !resetConfirmPending/,
  );
  assert.match(controls, /if \(root\.sliderNavigationEnabled\) \{/);
  assert.match(controls, /root\.cycleSlider\(-1\)/);
  assert.match(
    controls,
    /if \(root\.sliderNavigationEnabled && event\.key === Qt\.Key_Tab\) \{/,
  );
  const source = controls.match(
    /function cycleSlider\(direction: int\): void \{([\s\S]*?)\n    \}/,
  );
  assert.ok(source);
  const cycle = new Function(
    "sliderTargets",
    "selectedSlider",
    "direction",
    source[1] + "\nreturn selectedSlider;",
  );
  const targets = ["windows", "glass", "nightLight"];
  assert.equal(cycle(targets, "", 1), "windows");
  assert.equal(cycle(targets, "windows", 1), "glass");
  assert.equal(cycle(targets, "glass", 1), "nightLight");
  assert.equal(cycle(targets, "nightLight", -1), "glass");
  assert.equal(cycle(targets, "glass", -1), "windows");
});
