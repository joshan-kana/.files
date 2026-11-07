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
  assert.match(controls, /"Hardware unavailable"/);
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

test("Controls keeps a single responsive dashboard with existing dedicated details", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /id: commandMatrix/);
  assert.match(controls, /id: mediaMatrix/);
  assert.match(controls, /id: commandRight/);
  assert.ok(
    controls.includes(
      "columns: width >= 860 && root.theme.textScale < 1.4 ? 2 : 1",
    ),
  );
  assert.doesNotMatch(
    controls,
    /focusDirectory|focusGroup|controlsLayout|CONTROL SURFACE|ALL SYSTEMS/,
  );
  assert.match(controls, /onExpandRequested: root.openMixer\(\)/);
  assert.match(controls, /onFullRequested: root.mediaRequested\(\)/);
});

test("Controls preserves primary actions and shared audio/visual controls", () => {
  const controls = read("SystemContent.qml");
  for (const id of [
    "appearanceButton",
    "wallpaperButton",
    "sessionButton",
    "connectionTiles",
    "actionStrip",
    "visualModeStrip",
    "audioDeck",
    "commandRight",
    "trayItem",
    "brightnessHint",
  ])
    assert.match(controls, new RegExp("id: " + id));
  assert.match(controls, /ControlsMediaCard \{/);
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

test("Dashboard controls retain direct keys and no additional focus navigation mode", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /shortcut: "Q"\s+onActivated: root.openTheme\(\)/);
  assert.match(controls, /shortcut: "E"\s+onActivated: root.openSession\(\)/);
  assert.match(controls, /event.key === Qt.Key_Q\)\s*\{\s*root.openTheme\(\)/);
  assert.match(
    controls,
    /event.key === Qt.Key_E\)\s*\{\s*root.openSession\(\)/,
  );
  assert.doesNotMatch(controls, /toggleControlsLayout|moveFocusGroup|Shift\+I/);
  assert.match(controls, /audioDeck.deviceChooserOpen/);
});

test("The compact mixer uses content-driven height and does not delay rendering", () => {
  const mixer = read("AudioMixerContent.qml");
  assert.match(mixer, /compact \? Math.max\(1, body.implicitHeight/);
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.doesNotMatch(mixer, /id: expandAction/);
  assert.match(
    mixer,
    /monitoring: mixer.active && list.visible && streamRow.inViewport/,
  );
  assert.doesNotMatch(mixer, /setInterval|setTimeout|Timer \{/);
  assert.doesNotMatch(mixer, /shortcut: "ESC"/);
});

test("Dashboard hierarchy puts connectivity above Quick actions and audio/media at bottom", () => {
  const controls = read("SystemContent.qml");
  const appearance = controls.indexOf("id: appearanceSection");
  const connectivity = controls.indexOf("id: connectionTiles");
  const actions = controls.indexOf("id: actionStrip");
  const lower = controls.indexOf("id: mediaMatrix");
  const audio = controls.indexOf("id: audioSection");
  const media = controls.indexOf("ControlsMediaCard {");
  assert.ok(
    appearance >= 0 && appearance < connectivity && connectivity < actions,
  );
  assert.ok(actions < lower && lower < audio && audio < media);
  assert.match(controls, /title: "Quick actions"/);
  assert.match(controls, /title: "Connectivity"/);
  assert.match(
    controls,
    /id: appearanceSection[\s\S]*?width: commandMatrix.cellWidth/,
  );
  assert.match(
    controls,
    /id: audioSection[\s\S]*?width: mediaMatrix.cellWidth/,
  );
  assert.match(
    controls,
    /readonly property int columns: width < 440 \|\| root.theme.textScale >= 1.5 \? 2 : 3/,
  );
});

test("Compact Media keeps a small empty state and shares the full Now Playing destination", () => {
  const controls = read("SystemContent.qml");
  const card = read("ControlsMediaCard.qml");
  const transport = read("MediaTransport.qml");
  assert.match(controls, /ControlsMediaCard \{/);
  assert.match(controls, /onFullRequested: root.mediaRequested\(\)/);
  assert.match(card, /implicitHeight: media.available \? 260 : 212/);
  assert.match(
    card,
    /text: card.media.available \? card.media.title : "No active player"/,
  );
  assert.match(card, /simple: true/);
  assert.match(card, /shortcut: "N"/);
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(card, /id: fullPlayer|ShellAction \{/);
  assert.match(
    transport,
    /item.action === "previous" \|\| item.action === "play" \|\| item.action === "next"/,
  );
  assert.doesNotMatch(card, /lyrics|toggleShuffle|toggleRepeat|SpectrumBars/);
});

test("normal desktop tiles use two visual-mode rows without clipping controls", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /id: visualModeStrip[\s\S]*?readonly property int columns: width < 340[\s\S]*?width < 450 \? 3 : 5/,
  );
  assert.match(
    controls,
    /id: actionStrip[\s\S]*?readonly property int columns: width < 440[\s\S]*?root\.theme\.textScale >= 1\.5 \? 2 : 3/,
  );
  assert.match(controls, /function cellWidth\(index: int\): real/);
});

test("Unavailable hardware remains visible with consistent messaging and disabled brightness", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /detail: root.brightness.supported \? root.brightness.percent \+ "%"\s*: "Hardware unavailable"/,
  );
  assert.match(controls, /enabled: root.brightness.supported/);
  assert.match(
    controls,
    /onValueRequested: next => root.brightness.setPercent\(next\)/,
  );
  assert.match(
    controls,
    /root.system.networkDevices.length === 0 \? "Hardware unavailable"/,
  );
  assert.match(controls, /detail: unavailable \? "Hardware unavailable"/);
  assert.match(controls, /unavailable \? "" : root.system.networkConnected/);
  assert.match(controls, /unavailable \? "" : root.system.bluetoothEnabled/);
  assert.match(read("ConnectivityTile.qml"), /visible: tile.status.length > 0/);
  assert.match(controls, /id: connectionTiles/);
});

test("shared hub tabs expose hover, press and selected feedback", () => {
  const tabs = read("HubTabs.qml");
  for (const fragment of [
    "StateLayer {",
    "hoverOpacity: 0.13",
    "pressOpacity: 0.20",
    "onActivated: root.tabRequested(tab.modelData.destination)",
    "id: slidingSelection",
  ])
    assert.ok(tabs.includes(fragment));
});

test("two-row Session tiles use available horizontal space", () => {
  const session = read("SessionPanel.qml");
  for (const fragment of [
    "width: buttonGrid.width",
    "readonly property int rowCount: Math.min(",
    "actionRow.width - actionRow.spacing * (actionRow.rowCount - 1)",
    "readonly property int gridColumns: width < 340 ? 1 : width < 510 ? 2 : 3",
  ])
    assert.ok(session.includes(fragment), fragment);
});

test("main panel and compact Media use measured geometry with bounded empty state", () => {
  const controls = read("SystemContent.qml");
  const media = read("ControlsMediaCard.qml");
  const host = read("ShellExpansionHost.qml");
  for (const [source, fragment] of [
    [
      controls,
      "implicitWidth: detailsVisible ? theme.controlsDetailWidth : dashboardWidthBudget",
    ],
    [controls, "active: root.engaged && !root.detailsVisible"],
    [media, "implicitHeight: media.available ? 260 : 212"],
    [host, "height: Math.min(host.viewportHeight, host.targetHeight)"],
    [host, "(fraction - 0.68) / 0.30"],
  ])
    assert.ok(source.includes(fragment), fragment);
});

test("Controls consumes a bounded screen budget and distributes space across the dashboard", () => {
  const host = read("ShellExpansionHost.qml");
  const controls = read("SystemContent.qml");
  assert.match(host, /property: "dashboardWidthBudget"/);
  assert.match(
    host,
    /controlsPreferredWidth: screen \? Math.max\(theme.controlsDetailWidth, Math.min\(1480, screen.width \* 0.62\)\)/,
  );
  assert.match(
    host,
    /viewportWidth: screen \? Math.max\(1, Math.min\(screen.width - theme.spacing4 \* 2, controlsPreferredWidth \+ theme.spacing4 \* 2\)\)/,
  );
  assert.match(
    controls,
    /property real dashboardWidthBudget: theme.controlsDetailWidth/,
  );
  assert.match(host, /property: "dashboardHeightBudget"/);
  assert.match(host, /target: host.systemContent/);
  assert.match(
    host,
    /host.viewportHeight - tabs.implicitHeight - footerStatus.height - footerHints.implicitHeight/,
  );
  assert.match(controls, /property real dashboardHeightBudget: 0/);
  assert.match(
    controls,
    /dashboardBaseHeight: controlsClock.height \+ controlsHeading.height \+ commandMatrix.implicitHeight \+ mediaMatrix.implicitHeight/,
  );
  assert.match(controls, /dashboardHeightBudget - root.dashboardBaseHeight/);
  assert.match(controls, /id: trayRow/);
  assert.match(controls, /height: root.dashboardTileHeight/);
  assert.match(controls, /height: root.dashboardBrightnessHeight/);
  assert.match(controls, /height: root.dashboardConnectivityHeight/);
  assert.match(
    controls,
    /height: Math.max\(implicitHeight, audioDeck.implicitHeight\)/,
  );
});

test("compact widgets use clickable backgrounds, not dedicated full-view buttons", () => {
  const mixer = read("AudioMixerContent.qml");
  const media = read("ControlsMediaCard.qml");
  for (const [source, action] of [
    [mixer, "onActivated: mixer.expandRequested()"],
    [media, "onActivated: card.fullRequested()"],
  ]) {
    assert.match(source, /StateLayer \{/);
    assert.ok(source.includes(action));
  }
  assert.doesNotMatch(mixer, /id: expandAction|title: "Full mixer"/);
  assert.doesNotMatch(media, /id: fullPlayer|title: "Now Playing"/);
  assert.match(mixer, /shortcut: "SHIFT\+M"/);
  assert.match(media, /shortcut: "N"/);
  assert.match(mixer, /AudioDeviceControl \{/);
  assert.match(media, /MediaTransport \{/);
  assert.match(media, /ShellSlider \{/);
});

test("compact audio is one uncluttered group with input controls and conditional applications", () => {
  const mixer = read("AudioMixerContent.qml");
  const device = read("AudioDeviceControl.qml");
  const stream = read("AudioStreamControl.qml");
  assert.match(device, /fillColor: compact \? "transparent"/);
  assert.match(mixer, /visible: !mixer.compact \|\| mixer.streams.length > 0/);
  assert.match(mixer, /visible: !mixer.compact && mixer.streams.length === 0/);
  assert.match(device, /function toggleDeviceChooser\(\)/);
  assert.match(device, /system.toggleMicrophoneMute\(\)/);
  assert.match(device, /system.toggleMute\(\)/);
  assert.match(device, /system.setMicrophoneVolume\(value\)/);
  assert.match(device, /system.setVolume\(value\)/);
  assert.match(stream, /visible: !channel.compact/);
});

test("Quick Actions form two spacious rows with adaptive per-row widths", () => {
  const controls = read("SystemContent.qml");
  const start = controls.indexOf("id: actionStrip");
  const actions = controls.slice(
    start,
    controls.indexOf("ShellSection {", start),
  );
  assert.ok(actions.includes("root.theme.textScale >= 1.5 ? 2 : 3"));
  assert.ok(
    actions.includes(
      "const itemsInRow = Math.min(columns, 5 - Math.floor(index / columns) * columns)",
    ),
  );
});

test("compact Media anchors artwork and player information above footer controls", () => {
  const card = read("ControlsMediaCard.qml");
  assert.match(card, /height: card.heroSize/);
  assert.match(
    card,
    /parent.height - card.heroSize - \(card.media.available \? 26 : 0\) - 42/,
  );
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(card, /id: fullPlayer/);
});
