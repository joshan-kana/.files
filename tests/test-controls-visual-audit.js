const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const base = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(base, name), "utf8");

test("nine Controls visual modes form two consistent rows at normal desktop width", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /width < 450 \? 3 : 5/);
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
    /root\.cycleSlider\(event\.key === Qt\.Key_Backtab \|\| shifted \? -1 : 1\)/,
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
    /function cellWidth\(index: int\): real \{([\s\S]*?)\n\s+\}/,
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

test("one focused Controls handler owns forward and reverse slider traversal", () => {
  const controls = read("SystemContent.qml");
  const host = read("ShellExpansionHost.qml");
  assert.match(controls, /Keys.onShortcutOverride: event =>/);
  assert.match(
    controls,
    /event.key === Qt.Key_Tab \|\| event.key === Qt.Key_Backtab/,
  );
  assert.match(
    controls,
    /root\.cycleSlider\(event.key === Qt.Key_Backtab \|\| shifted \? -1 : 1\)/,
  );
  assert.match(controls, /keyboardFocus\.forceActiveFocus\(\)/);
  assert.doesNotMatch(host, /sequence: "Shift\+Tab"/);
  assert.doesNotMatch(host, /autoRepeat: false/);
  assert.match(
    read("shell.qml"),
    /function controlsSelectedSlider\(\): string/,
  );
  const source = controls.match(
    /function cycleSlider\(direction: int\): void \{([\s\S]*?)\n    \}/,
  );
  assert.ok(source);
  const cycle = new Function(
    "sliderTargets",
    "selectedSlider",
    "direction",
    "keyboardFocus",
    source[1] + "\nreturn selectedSlider;",
  );
  const targets = ["windows", "glass", "nightLight"];
  const focus = { forceActiveFocus() {} };
  let current = "";
  for (const direction of [1, 1, 1, -1, -1, -1, -1])
    current = cycle(targets, current, direction, focus);
  assert.equal(current, "glass");
});

test("active slider status does not masquerade as keyboard focus after reverse traversal", () => {
  for (const name of ["OpacitySetting.qml", "AdjustableSetting.qml"]) {
    const tile = read(name);
    assert.match(tile, /outlined: keyboardSelected/);
    assert.match(
      tile,
      /borderWidth: keyboardSelected \? theme\.borderFocus : 0/,
    );
    assert.match(
      tile,
      /borderColor: keyboardSelected \? theme\.blend\(roleAccent, theme\.textStrong, 0\.55\) : "transparent"/,
    );
    assert.match(tile, /luminous: active \|\| keyboardSelected/);
    assert.match(
      tile,
      /fillColor: active \? theme\.blend\(theme\.controlBase, roleAccent,/,
    );
    assert.doesNotMatch(tile, /outlined: active \|\| keyboardSelected/);
  }
});

test("modifier-only keys cannot clear slider selection across repeated Shift+Tab presses", () => {
  const controls = read("SystemContent.qml");
  const host = read("ShellExpansionHost.qml");
  const keyCode = controls
    .split("Keys.onPressed: event => {")[1]
    .split("if (root.selectedSlider.length > 0)")[0];
  assert.match(
    keyCode,
    /event.key === Qt.Key_Shift \|\| event.key === Qt.Key_Control/,
  );
  assert.match(keyCode, /event.accepted = true;\s*return;/);
  const shiftGuard = keyCode.indexOf("event.key === Qt.Key_Shift");
  const backtab = keyCode.indexOf(
    "root.cycleSlider(event.key === Qt.Key_Backtab || shifted ? -1 : 1)",
  );
  const selectionReset = controls.indexOf(
    'root.selectedSlider = ""',
    controls.indexOf("Keys.onPressed: event => {"),
  );
  assert.ok(shiftGuard >= 0 && shiftGuard < backtab);
  assert.ok(backtab >= 0 && backtab < selectionReset);
  assert.doesNotMatch(host, /sequence: "Shift\+Tab"/);
});

test("Controls uses an adaptive compound matrix and a focused workspace", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /implicitWidth: themeOpen \|\| wallpaperOpen \? theme\.controlsDetailWidth : 1020/,
  );
  assert.match(controls, /id: commandMatrix/);
  assert.match(controls, /id: audioSection/);
  assert.match(controls, /id: everydaySection/);
  assert.match(controls, /id: appearanceSection/);
  assert.match(controls, /id: focusDirectory/);
  assert.match(
    controls,
    /root\.controlsLayout === "matrix" \? "Focus" : "Matrix"/,
  );
  assert.match(controls, /function moveFocusGroup\(delta: int\)/);
  assert.match(controls, /shifted && event\.key === Qt\.Key_I/);
  assert.match(controls, /root\.controlsLayout === "focus" && shifted/);
});

test("Controls keeps all visual controls and primary detail destinations", () => {
  const controls = read("SystemContent.qml");
  for (const id of [
    "appearanceButton",
    "wallpaperButton",
    "sessionButton",
    "connectionTiles",
    "actionStrip",
    "visualModeStrip",
    "audioDeck",
    "mediaInlineTransport",
    "mediaQuickExtras",
    "trayItem",
    "brightnessHint",
  ])
    assert.match(controls, new RegExp("id: " + id));
  for (const action of [
    "openTheme",
    "openWallpaper",
    "openSession",
    "openNetwork",
    "openBluetooth",
    "openResources",
    "openRecordings",
    "openMixer",
  ])
    assert.match(controls, new RegExp("root\\." + action + "\\("));
});

test("focus directory reflows while preserving the same actions and local shortcuts", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /readonly property int columns: width < 680 \|\| root\.theme\.textScale >= 1\.5 \? 2 : 4/,
  );
  assert.match(controls, /root\.controlsLayout === "matrix" && width >= 820/);
  assert.match(
    controls,
    /root\.controlsLayout === "matrix" \|\| root\.focusGroup === "audio"/,
  );
  assert.match(
    controls,
    /root\.controlsLayout === "matrix" \|\| root\.focusGroup === "appearance"/,
  );
  assert.match(controls, /shifted && event\.key === Qt\.Key_I/);
  assert.match(
    controls,
    /root\.moveFocusGroup\(event\.key === Qt\.Key_J \? 1 : -1\)/,
  );
  assert.match(controls, /audioDeck\.deviceChooserOpen/);
});

test("the compact mixer reserves first-frame geometry without delaying rendering", () => {
  const mixer = read("AudioMixerContent.qml");
  assert.match(mixer, /compact \? Math\.max\(300, body\.implicitHeight/);
  assert.match(mixer, /body\.implicitHeight < 140/);
  assert.match(
    mixer,
    /monitoring: mixer\.active && list\.visible && streamRow\.inViewport/,
  );
  assert.doesNotMatch(mixer, /setInterval|setTimeout|Timer \{/);
  assert.doesNotMatch(mixer, /shortcut: "ESC"/);
});

test("Controls positions visual modes above audio and media in the adaptive matrix", () => {
  const controls = read("SystemContent.qml");
  const visual = controls.indexOf("id: appearanceSection");
  const everyday = controls.indexOf("id: everydaySection");
  const bottom = controls.indexOf("id: mediaMatrix");
  const audio = controls.indexOf("id: audioSection");
  const media = controls.indexOf('text: root.media.available ? "MEDIA"');
  assert.ok(visual > 0 && visual < everyday && everyday < bottom);
  assert.ok(bottom < audio && audio < media);
  assert.match(
    controls,
    /id: appearanceSection[\s\S]*?width: commandMatrix\.cellWidth/,
  );
  assert.match(
    controls,
    /id: audioSection[\s\S]*?width: mediaMatrix\.cellWidth/,
  );
  assert.match(
    controls,
    /id: mediaMatrix[\s\S]*?columns: root\.controlsLayout === "matrix" && width >= 820/,
  );
  assert.match(
    controls,
    /width < 410 \|\| root\.theme\.textScale >= 1\.3 \? 2 : width < 450 \? 3 : 5/,
  );
});

test("the media slot has a bounded empty state and preserves its Now Playing action", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /visible: !root\.media\.available[\s\S]*?Accessible\.name: "Open Now Playing"/,
  );
  assert.match(controls, /height: visible \? 248 : 0/);
  assert.match(controls, /onActivated: root\.mediaRequested\(\)/);
  assert.match(controls, /text: "No active player"/);
});

test("normal desktop tiles use two visual-mode rows without clipping controls", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /id: visualModeStrip[\s\S]*?readonly property int columns: width < 340[\s\S]*?width < 450 \? 3 : 5/,
  );
  assert.match(
    controls,
    /id: actionStrip[\s\S]*?readonly property int columns: width < 410[\s\S]*?width < 450 \|\| root\.theme\.textScale >= 1\.3 \? 3 : 5/,
  );
  assert.match(controls, /function cellWidth\(index: int\): real/);
});

test("focused Controls category order follows the matrix's spatial hierarchy", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /property string focusGroup: "appearance"/);
  assert.match(
    controls,
    /readonly property var focusGroups: \["appearance", "everyday", "audio", "media"\]/,
  );
  const first = controls.indexOf(
    'key: "appearance"',
    controls.indexOf("id: focusDirectory"),
  );
  const second = controls.indexOf('key: "everyday"', first);
  const third = controls.indexOf('key: "audio"', second);
  const fourth = controls.indexOf('key: "media"', third);
  assert.ok(first > 0 && first < second && second < third && third < fourth);
});
