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
  assert.match(tile, /id: adjustHint[\s\S]*?shortcut: "H\/L"/);
  assert.match(tile, /shortcut: setting\.toggleShortcut/);
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
  assert.match(opacity, /shortcut: setting\.shortcut/);
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
  assert.match(
    mixer,
    /implicitHeight: body.implicitHeight \+ \(compact \? theme.spacing4 \* 2/,
  );
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.doesNotMatch(mixer, /id: expandAction/);
  assert.match(
    mixer,
    /monitoring: mixer.active && list.visible && streamRow.inViewport/,
  );
  assert.doesNotMatch(mixer, /setInterval|setTimeout|Timer \{/);
  assert.doesNotMatch(mixer, /shortcut: "ESC"/);
});

test("Dashboard hierarchy retains balanced two-row quick actions and bottom audio/media", () => {
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
    /readonly property int columns: width < 440 \|\| root.theme.textScale >= 1\.5 \? 2 : 3/,
  );
  assert.match(
    controls,
    /const itemsInRow = Math\.min\(columns, 5 - row \* columns\)/,
  );
  assert.match(
    controls,
    /height: Math.max\(implicitHeight, mediaCard.implicitHeight\)/,
  );
  assert.match(
    controls,
    /height: Math.max\(implicitHeight, audioDeck.implicitHeight\)/,
  );
});

test("Compact Media shares a live spectrum, controls and full Now Playing navigation", () => {
  const controls = read("SystemContent.qml");
  const card = read("ControlsMediaCard.qml");
  const transport = read("MediaTransport.qml");
  assert.match(controls, /onFullRequested: root.mediaRequested\(\)/);
  assert.match(controls, /spectrum: root.spectrum/);
  assert.match(card, /implicitHeight: media.available \? 178 : 152/);
  assert.match(
    card,
    /text: card.media.available \? card.media.title : "No active player"/,
  );
  assert.match(card, /simple: card.width < 490/);
  assert.match(card, /id: compactTransport[\s\S]*?minimal: true/);
  assert.match(
    card,
    /parent.width - shuffleButton.width - repeatButton.width - compactTransport.width/,
  );
  assert.match(card, /SpectrumBars \{/);
  assert.match(card, /barCount: 24/);
  assert.match(
    card,
    /shortcut: "Z"[\s\S]*?onActivated: card.media.toggleShuffle\(\)/,
  );
  assert.match(
    card,
    /shortcut: "B"[\s\S]*?onActivated: card.media.toggleRepeat\(\)/,
  );
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(card, /id: fullPlayer|lyrics/);
  assert.match(
    transport,
    /item.action === "previous" \|\| item.action === "play" \|\| item.action === "next"/,
  );
});

test("Visual modes retain their two-row layout independently of Quick Actions", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /id: visualModeStrip[\s\S]*?readonly property int columns: width < 340[\s\S]*?width < 450 \? 3 : 5/,
  );
  assert.match(
    controls,
    /id: actionStrip[\s\S]*?readonly property int columns: width < 440 \|\| root.theme.textScale >= 1\.5 \? 2 : 3/,
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

test("Session actions keep their natural size in three-plus-two rows", () => {
  const session = read("SessionPanel.qml");
  assert.match(
    session,
    /width: Math.min\(parent.width, panel.gridColumns \* 154/,
  );
  assert.match(
    session,
    /implicitWidth: 3 \* 154 \+ 2 \* theme.spacing3 \+ theme.spacing5 \* 2/,
  );
  assert.match(
    read("SystemContent.qml"),
    /implicitWidth: sessionPanel.open \? sessionPanel.implicitWidth/,
  );
  assert.match(session, /width: Math.min\(buttonGrid.width, rowCount \* 154/);
  assert.match(session, /anchors.horizontalCenter: parent.horizontalCenter/);
  assert.match(session, /readonly property int rowCount: Math.min\(/);
  assert.match(
    session,
    /actionRow.width - actionRow.spacing \* \(actionRow.rowCount - 1\)/,
  );
  assert.match(
    session,
    /readonly property int gridColumns: width < 340 \? 1 : width < 510 \? 2 : 3/,
  );
});

test("main panel and compact Media use measured geometry with bounded empty state", () => {
  const controls = read("SystemContent.qml");
  const media = read("ControlsMediaCard.qml");
  const host = read("ShellExpansionHost.qml");
  for (const [source, fragment] of [
    [
      controls,
      "implicitWidth: sessionPanel.open ? sessionPanel.implicitWidth : detailsVisible ? theme.controlsDetailWidth : dashboardWidthBudget",
    ],
    [controls, "active: root.engaged && !root.detailsVisible"],
    [media, "implicitHeight: media.available ? 178 : 152"],
    [host, "height: Math.min(host.viewportHeight, host.targetHeight)"],
    [host, "(fraction - 0.68) / 0.30"],
  ])
    assert.ok(source.includes(fragment), fragment);
});

test("Controls sizes naturally without inflating tiles or forcing scroll hints", () => {
  const host = read("ShellExpansionHost.qml");
  const controls = read("SystemContent.qml");
  assert.match(host, /property: "dashboardWidthBudget"/);
  assert.match(host, /Math.min\(1340, screen.width \* 0.54\)/);
  assert.doesNotMatch(host, /property: "dashboardHeightBudget"/);
  assert.doesNotMatch(
    controls,
    /dashboardHeightBudget|dashboardBaseHeight|dashboardGaps/,
  );
  assert.match(controls, /spacing: root.theme.spacing3/);
  assert.match(controls, /dashboardTileHeight: 72/);
  assert.match(controls, /dashboardBrightnessHeight: 90/);
  assert.match(controls, /dashboardConnectivityHeight: 84/);
  assert.match(
    controls,
    /height: Math.max\(implicitHeight, mediaCard.implicitHeight\)/,
  );
  assert.match(
    controls,
    /height: Math.max\(implicitHeight, audioDeck.implicitHeight\)/,
  );
});

test("Compact Audio and Media backgrounds open full views while child actions remain independent", () => {
  const mixer = read("AudioMixerContent.qml");
  const media = read("ControlsMediaCard.qml");
  const controls = read("SystemContent.qml");
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.match(media, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(mixer, /id: expandAction|title: "Full mixer"/);
  assert.doesNotMatch(media, /id: fullPlayer|title: "Now Playing"/);
  assert.match(
    controls,
    /shifted && event.key === Qt.Key_M\)\s*\{\s*root.openMixer\(\)/,
  );
  assert.doesNotMatch(
    controls.slice(
      controls.indexOf('title: "Media"'),
      controls.indexOf("ControlsMediaCard {"),
    ),
    /hints: \[/,
  );
  assert.match(mixer, /AudioDeviceControl \{/);
  assert.match(media, /MediaTransport \{/);
  assert.match(media, /ShellSlider \{/);
});

test("Compact Audio keeps Output/Input without app rows and shows correct header hints", () => {
  const mixer = read("AudioMixerContent.qml");
  const device = read("AudioDeviceControl.qml");
  const controls = read("SystemContent.qml");
  assert.match(mixer, /columns: width >= \(mixer.compact \? 440 : 600\)/);
  assert.match(mixer, /model: mixer.compact \? 0 : mixer.streams.length/);
  assert.match(mixer, /visible: !mixer.compact && mixer.streams.length > 0/);
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.match(device, /fillColor: compact \? "transparent"/);
  for (const fragment of [
    "toggleDeviceChooser",
    "system.toggleMicrophoneMute()",
    "system.toggleMute()",
    "system.setMicrophoneVolume(value)",
    "system.setVolume(value)",
  ])
    assert.ok(device.includes(fragment), fragment);
  for (const fragment of [
    /shortcut: "J\/K",\s*label: "Select"/,
    /shortcut: "H\/L",\s*label: "Level"/,
  ])
    assert.match(controls, fragment);
  assert.match(read("ShellSection.qml"), /id: headerHints/);
});

test("Quick Actions fill both rows without changing tile height", () => {
  const controls = read("SystemContent.qml");
  const start = controls.indexOf("id: actionStrip");
  const actions = controls.slice(
    start,
    controls.indexOf("ShellSection {", start),
  );
  assert.match(
    actions,
    /width < 440 \|\| root.theme.textScale >= 1\.5 \? 2 : 3/,
  );
  const expression = actions.match(
    /function cellWidth\(index: int\): real \{([\s\S]*?)\n\s+\}/,
  );
  assert.ok(expression);
  const cellWidth = new Function(
    "index",
    "columns",
    "width",
    "spacing",
    expression[1],
  );
  for (const columns of [2, 3]) {
    for (let row = 0; row < Math.ceil(5 / columns); row++) {
      const count = Math.min(columns, 5 - row * columns);
      const widths = Array.from({ length: count }, (_, i) =>
        cellWidth(row * columns + i, columns, 615, 8),
      );
      assert.ok(widths.every((value) => value > 0));
      assert.ok(
        Math.abs(widths.reduce((a, b) => a + b, 0) + (count - 1) * 8 - 615) <
          0.01,
      );
    }
  }
  assert.match(actions, /height: root.dashboardTileHeight/);
});

test("compact Media anchors artwork and player information above footer controls", () => {
  const card = read("ControlsMediaCard.qml");
  assert.match(card, /height: card.heroSize/);
  assert.match(card, /implicitHeight: media.available \? 178 : 152/);
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(card, /id: fullPlayer/);
});

test("hub expansion accounts for the actual inner viewport margins", () => {
  const host = read("ShellExpansionHost.qml");
  for (const fragment of [
    "tabs.anchors.topMargin",
    "contentViewport.anchors.topMargin",
    "contentViewport.anchors.bottomMargin",
    "footerBottomClearance",
  ])
    assert.ok(host.includes(fragment), fragment);
  assert.match(host, /readonly property real contentHeight: loadedContent/);
  assert.match(host, /measuredContentHeight = loadedContent.implicitHeight/);
  assert.doesNotMatch(host, /PR211_TEMP_GEOMETRY/);
});

test("Session uses compact hub width, not the Controls dashboard width", () => {
  const controls = read("SystemContent.qml");
  const session = read("SessionPanel.qml");
  const host = read("ShellExpansionHost.qml");
  assert.match(
    controls,
    /implicitWidth: sessionPanel.open \? sessionPanel.implicitWidth : detailsVisible \? theme.controlsDetailWidth : dashboardWidthBudget/,
  );
  assert.match(
    session,
    /implicitWidth: 3 \* 154 \+ 2 \* theme.spacing3 \+ theme.spacing5 \* 2/,
  );
  assert.match(host, /Math.max\(loadedContent.implicitWidth, 600\)/);
  assert.match(host, /width: Math.min\(host.viewportWidth, host.targetWidth\)/);
});

test("Controls Media transport has centered playback and all available seek controls", () => {
  const card = read("ControlsMediaCard.qml");
  const transport = read("MediaTransport.qml");
  assert.match(
    card,
    /id: shuffleButton[\s\S]*?id: compactTransport[\s\S]*?id: repeatButton/,
  );
  assert.match(card, /simple: card.width < 490/);
  assert.match(card, /id: compactTransport[\s\S]*?width: implicitWidth/);
  assert.match(transport, /action: "back"/);
  assert.match(transport, /action: "forward"/);
  assert.match(transport, /action: "play"/);
  assert.match(card, /spectrum: card.spectrum/);
});
test("slider mode retains Tab, J/K selection and H/L edits without duplicate legends", () => {
  const controls = read("SystemContent.qml");
  const opacity = read("OpacitySetting.qml");
  const night = read("AdjustableSetting.qml");
  assert.match(controls, /id: sliderNavigationHint[\s\S]*?shortcut: "J\/K"/);
  assert.match(controls, /event.key === Qt.Key_K \|\| event.key === Qt.Key_Up/);
  assert.match(
    controls,
    /event.key === Qt.Key_J \|\| event.key === Qt.Key_Down/,
  );
  assert.match(controls, /root.adjustSlider\(-1\)/);
  assert.match(controls, /root.adjustSlider\(1\)/);
  assert.match(opacity, /shortcut: setting.shortcut/);
  assert.match(night, /shortcut: setting.toggleShortcut/);
  for (const tile of [opacity, night]) {
    assert.match(tile, /id: adjustHint[\s\S]*?shortcut: "H\/L"/);
    assert.match(tile, /hovered: tileHover.hovered/);
  }
  assert.doesNotMatch(
    controls.slice(
      controls.indexOf('title: "Media"'),
      controls.indexOf("ControlsMediaCard {"),
    ),
    /hints: \[/,
  );
});
