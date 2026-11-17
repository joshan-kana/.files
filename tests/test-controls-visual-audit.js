const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const base = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(base, name), "utf8");

// Evaluate the QML layout expressions with varying widths, text scales and
// tile counts so changes to the actual bindings cannot silently break wrapping.
const tileLayout = (controls, width, textScale, count, spacing = 8) => {
  const canvas = controls
    .split("id: controlTiles")[1]
    .split("QuickSettingChip {")[0];
  const scope = {
    root: { theme: { textScale } },
    width,
    spacing,
    children: { length: count },
  };
  for (const property of [
    "minimumTileWidth",
    "capacity",
    "rows",
    "columns",
    "cellWidth",
  ]) {
    const expression = canvas.match(
      new RegExp(`readonly property (?:real|int) ${property}: ([^\n]+)`),
    )?.[1];
    assert.ok(expression, `missing QML tile layout binding ${property}`);
    scope[property] = new Function(
      ...Object.keys(scope),
      `return (${expression});`,
    )(...Object.values(scope));
  }
  return scope;
};

test("hover and press motion on shared Controls tiles stays inside the clipped viewport", () => {
  for (const name of [
    "QuickSettingChip.qml",
    "OpacitySetting.qml",
    "AdjustableSetting.qml",
    "ConnectivityTile.qml",
  ]) {
    const scale = read(name).match(/^\s*scale:\s*[^\n]+$/m)?.[0];
    assert.ok(scale, `${name} must expose its interaction scale`);
    const values = scale.match(/\b\d+(?:\.\d+)?\b/g).map(Number);
    assert.equal(
      values.length,
      3,
      `${name} needs press, hover and rest scales`,
    );
    const [pressed, hovered, resting] = values;
    assert.ok(pressed < resting, `${name} press should shrink`);
    assert.ok(resting < hovered, `${name} hover should grow from rest`);
    assert.equal(hovered, 1, `${name} hover must not exceed its layout bounds`);
  }
});

test("Visual Modes and Quick Actions share one continuous 14-tile canvas", () => {
  const controls = read("SystemContent.qml");
  const tiles = controls
    .split("id: controlTiles")[1]
    .split("ShellSurface {")[0];
  assert.equal(
    (tiles.match(/width: controlTiles\.cellWidth/g) || []).length,
    14,
  );
  assert.equal((tiles.match(/QuickSettingChip \{/g) || []).length, 11);
  assert.equal((tiles.match(/OpacitySetting \{/g) || []).length, 2);
  assert.equal((tiles.match(/AdjustableSetting \{/g) || []).length, 1);
  assert.match(controls, /id: quickActionsHeading/);
  assert.match(controls, /text: "VISUAL MODES"/);
  assert.match(controls, /text: "· QUICK ACTIONS"/);
  assert.doesNotMatch(
    controls,
    /id: (?:visualModeStrip|actionStrip|commandRight)/,
  );
});

test("night light uses inline, interactive slider with value and shared KeyHint", () => {
  const controls = read("SystemContent.qml");
  const tile = read("AdjustableSetting.qml");
  const state = read("NightLightState.qml");
  assert.match(controls, /label: "Night Light"/);
  assert.match(
    controls,
    /toggleShortcut: root\.runtime\.shellHint\("SystemContent\.nightLight"\)/,
  );
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
  assert.match(
    tile,
    /shortcut: setting\.keyboardSelected \? setting\.runtime\.shellHint\("AdjustableSetting.level"\) : setting\.toggleShortcut/,
  );
  assert.equal((tile.match(/KeyHint \{/g) || []).length, 1);
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
    /root\.cycleSlider\(event\.key === root\.runtime\.shellKeyCode\("controls", "Backtab"\) \|\| shifted \? -1 : 1\)/,
  );
  assert.match(controls, /root\.selectedSlider = ""/);
  assert.match(
    controls,
    /if \(event\.key === root\.runtime\.shellKeyCode\("controls", "Escape"\)\) \{\s*root\.navigateBack\(\);/,
  );
  assert.match(
    controls,
    /shortcut: root\.runtime\.shellHint\("SystemContent.tabSelect"\)/,
  );
  assert.match(
    controls,
    /hints: root\.selectedSlider\.length === 0 \? \[\s*\{\s*shortcut: root\.runtime\.shellHint\("SystemContent.audioSelect"\)/,
  );
  assert.match(read("ShellSection.qml"), /trailing: true/);
  assert.match(
    opacity,
    /shortcut: setting\.keyboardSelected \? setting\.runtime\.shellHint\("OpacitySetting.level"\) : setting\.shortcut/,
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
  assert.match(
    host,
    /shortcut: host\.runtime\.shellHint\("ShellExpansionHost.back"\)[\s\S]*?label: host\.escapeHintLabel/,
  );
});

test("tile rows adapt to panel width, text scale and added or removed actions", () => {
  const controls = read("SystemContent.qml");
  for (const width of [320, 420, 560, 860, 1120]) {
    for (const scale of [1, 1.25, 1.5, 2]) {
      for (const count of [1, 5, 9, 12, 13, 14, 15, 16, 17, 21, 22]) {
        const layout = tileLayout(controls, width, scale, count);
        assert.ok(layout.columns >= 1 && layout.columns <= layout.capacity);
        assert.ok(layout.rows * layout.columns >= count);
        assert.ok((layout.rows - 1) * layout.columns < count);
        assert.ok(layout.cellWidth >= layout.minimumTileWidth - 0.01);
        assert.ok(
          layout.columns * layout.cellWidth + (layout.columns - 1) * 8 <=
            width + 0.01,
        );
      }
    }
  }
  for (const [width, scale, count, columns, rows] of [
    [1120, 1, 14, 7, 2],
    [1120, 1, 15, 5, 3],
    [1120, 1, 16, 6, 3],
    [1120, 1.5, 14, 5, 3],
    [560, 1, 14, 3, 5],
  ]) {
    const layout = tileLayout(controls, width, scale, count);
    assert.equal(layout.columns, columns);
    assert.equal(layout.rows, rows);
  }
});

test("one focused Controls handler owns forward and reverse slider traversal", () => {
  const controls = read("SystemContent.qml");
  const host = read("ShellExpansionHost.qml");
  assert.match(controls, /Keys.onShortcutOverride: event =>/);
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "Tab"\) \|\| event\.key === root\.runtime\.shellKeyCode\("controls", "Backtab"\)/,
  );
  assert.match(
    controls,
    /root\.cycleSlider\(event\.key === root\.runtime\.shellKeyCode\("controls", "Backtab"\) \|\| shifted \? -1 : 1\)/,
  );
  assert.match(controls, /keyboardFocus\.forceActiveFocus\(\)/);
  assert.doesNotMatch(host, /sequence: "Shift\+Tab"/);
  assert.doesNotMatch(host, /autoRepeat: false/);
  assert.match(
    read("shell.qml"),
    /function controlsSelectedSlider\(\): string/,
  );
  const source = controls.match(
    /function cycleSlider\(direction: int\): void \{([\s\S]*?)\n {4}\}/,
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
    /event\.key === root\.runtime\.shellKeyCode\("controls", "Shift"\) \|\| event\.key === root\.runtime\.shellKeyCode\("controls", "Control"\)/,
  );
  assert.match(keyCode, /event.accepted = true;\s*return;/);
  const shiftGuard = keyCode.indexOf(
    'event.key === root.runtime.shellKeyCode("controls", "Shift")',
  );
  const backtab = keyCode.indexOf(
    'root.cycleSlider(event.key === root.runtime.shellKeyCode("controls", "Backtab") || shifted ? -1 : 1)',
  );
  const selectionReset = controls.indexOf(
    'root.selectedSlider = ""',
    controls.indexOf("Keys.onPressed: event => {"),
  );
  assert.ok(shiftGuard >= 0 && shiftGuard < backtab);
  assert.ok(backtab >= 0 && backtab < selectionReset);
  assert.doesNotMatch(host, /sequence: "Shift\+Tab"/);
});

test("Controls keeps paired primary controls and one responsive canvas above audio/media", () => {
  const controls = read("SystemContent.qml");
  assert.match(controls, /id: commandMatrix/);
  assert.match(controls, /id: tileCanvas/);
  assert.match(controls, /id: controlTiles/);
  assert.match(controls, /id: mediaMatrix/);
  assert.match(
    controls,
    /columns: width >= 860 && root.theme.textScale < 1.4 \? 2 : 1/,
  );
  assert.match(controls, /height: root.dashboardBrightnessHeight/);
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
    "tileCanvas",
    "controlTiles",
    "audioDeck",
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
  assert.match(
    controls,
    /shortcut: root\.runtime\.shellHint\("SystemContent.themes"\)\s+onActivated: root.openTheme\(\)/,
  );
  assert.match(
    controls,
    /shortcut: root\.runtime\.shellHint\("SystemContent.session"\)\s+onActivated: root.openSession\(\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "Q"\)\)\s*\{\s*root.openTheme\(\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "E"\)\)\s*\{\s*root.openSession\(\)/,
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

test("Dashboard hierarchy puts the shared tile canvas between top controls and media", () => {
  const controls = read("SystemContent.qml");
  const appearance = controls.indexOf("id: appearanceSection");
  const connectivity = controls.indexOf("id: connectionTiles");
  const tiles = controls.indexOf("id: controlTiles");
  const lower = controls.indexOf("id: mediaMatrix");
  const audio = controls.indexOf("id: audioSection");
  const media = controls.indexOf("ControlsMediaCard {");
  assert.ok(
    appearance >= 0 && appearance < connectivity && connectivity < tiles,
  );
  assert.ok(tiles < lower && lower < audio && audio < media);
  assert.match(controls, /title: "Connectivity"/);
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
    /Row \{\s+width: implicitWidth[\s\S]*?anchors.horizontalCenter: parent.horizontalCenter/,
  );
  assert.doesNotMatch(card, /parent.width - shuffleButton.width/);
  assert.match(card, /SpectrumBars \{/);
  assert.match(card, /barCount: 24/);
  assert.match(
    card,
    /shortcut: card\.runtime\.shellHint\("ControlsMediaCard.shuffle"\)[\s\S]*?onActivated: card.media.toggleShuffle\(\)/,
  );
  assert.match(
    card,
    /shortcut: card\.runtime\.shellHint\("ControlsMediaCard.repeat"\)[\s\S]*?onActivated: card.media.toggleRepeat\(\)/,
  );
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.doesNotMatch(card, /id: fullPlayer|lyrics/);
  assert.match(
    transport,
    /item.action === "previous" \|\| item.action === "play" \|\| item.action === "next"/,
  );
});

test("Visual Modes and Quick Actions use the same calculated width and wrap", () => {
  const controls = read("SystemContent.qml");
  assert.match(
    controls,
    /readonly property real minimumTileWidth: 140 \* root.theme.textScale/,
  );
  assert.match(
    controls,
    /readonly property int capacity: Math.max\(1, Math.min\(7,/,
  );
  assert.match(
    controls,
    /readonly property int rows: Math.max\(1, Math.ceil\(children.length \/ capacity\)\)/,
  );
  assert.match(
    controls,
    /readonly property int columns: Math.max\(1, Math.ceil\(children.length \/ rows\)\)/,
  );
  assert.match(controls, /readonly property real cellWidth:/);
  assert.equal(
    (controls.match(/width: controlTiles\.cellWidth/g) || []).length,
    14,
  );
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
  assert.doesNotMatch(controls, /dashboardConnectivityHeight/);
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
    /shifted && event\.key === root\.runtime\.shellKeyCode\("controls", "M"\)\)\s*\{\s*root\.openMixer\(\)/,
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
    /shortcut: root\.runtime\.shellHint\("SystemContent.audioSelect"\),\s*label: "Select"/,
    /shortcut: root\.runtime\.shellHint\("SystemContent.audioAdjust"\),\s*label: "Level"/,
  ])
    assert.match(controls, fragment);
  assert.match(read("ShellSection.qml"), /id: headerHints/);
});

test("Quick Actions retain their order and direct action handlers in the shared canvas", () => {
  const controls = read("SystemContent.qml");
  const tiles = controls
    .split("id: controlTiles")[1]
    .split("ShellSurface {")[0];
  const actions = [
    'title: root.notificationState.silent ? "Silent" : "Alerts"',
    'title: root.system.idleInhibited ? "Stay awake" : "Idle allowed"',
    'title: (root.powerProfile.available ? root.powerProfile.label(root.powerProfile.current) : "Power")',
    'title: "Resources"',
    'title: "Captures"',
  ];
  let previous = tiles.indexOf('title: root.resetRunning ? "Restoring…"');
  for (const action of actions) {
    const index = tiles.indexOf(action);
    assert.ok(index > previous, action);
    previous = index;
  }
  assert.match(tiles, /onActivated: root.openResources\(\)/);
  assert.match(tiles, /onActivated: root.openRecordings\(\)/);
});

test("all 14 tile heights remain fixed as the canvas is rebalanced", () => {
  const controls = read("SystemContent.qml");
  const tiles = controls
    .split("id: controlTiles")[1]
    .split("ShellSurface {")[0];
  assert.equal(
    (tiles.match(/height: root.dashboardTileHeight/g) || []).length,
    14,
  );
  assert.match(controls, /readonly property int dashboardTileHeight: 72/);
  for (const count of [13, 14, 15, 16, 20]) {
    const layout = tileLayout(controls, 1120, 1, count);
    assert.ok(layout.columns * 72 > 0);
    assert.equal(layout.rows, Math.ceil(count / layout.capacity));
  }
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

test("Controls Media groups shuffle, transport, and repeat in one centered row", () => {
  const card = read("ControlsMediaCard.qml");
  const transport = read("MediaTransport.qml");
  assert.match(
    card,
    /Row \{\s+width: implicitWidth[\s\S]*?anchors.horizontalCenter: parent.horizontalCenter/,
  );
  assert.match(
    card,
    /id: shuffleButton[\s\S]*?id: compactTransport[\s\S]*?id: repeatButton/,
  );
  assert.doesNotMatch(card, /parent.width - shuffleButton.width/);
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
  assert.match(
    controls,
    /id: sliderNavigationHint[\s\S]*?shortcut: root\.runtime\.shellHint\("SystemContent.rowSelect"\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "K"\) \|\| event\.key === root\.runtime\.shellKeyCode\("controls", "Up"\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "J"\) \|\| event\.key === root\.runtime\.shellKeyCode\("controls", "Down"\)/,
  );
  assert.match(controls, /root.adjustSlider\(-1\)/);
  assert.match(controls, /root.adjustSlider\(1\)/);
  assert.match(
    opacity,
    /shortcut: setting\.keyboardSelected \? setting\.runtime\.shellHint\("OpacitySetting.level"\) : setting\.shortcut/,
  );
  assert.match(
    night,
    /shortcut: setting\.keyboardSelected \? setting\.runtime\.shellHint\("AdjustableSetting.level"\) : setting\.toggleShortcut/,
  );
  for (const tile of [opacity, night]) {
    assert.equal((tile.match(/TileKeyHint \{/g) || []).length, 1);
    assert.match(
      tile,
      /TileKeyHint \{[\s\S]*?shortcut: setting.keyboardSelected/,
    );
    assert.doesNotMatch(tile, /id: adjustHint|adjustHint\.implicitWidth/);
    assert.match(tile, /ShellSlider \{\s*width: parent.width/);
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

test("Visual Modes tile keycaps use one shared corner and motion convention", () => {
  const shared = read("TileKeyHint.qml");
  assert.match(shared, /property real cornerInset: theme\.spacing2/);
  assert.match(
    shared,
    /property real animatedInset: circular \? circleInset : cornerInset/,
  );
  assert.match(shared, /Behavior on animatedInset \{\s*Anim \{/);
  assert.match(shared, /motion: hint\.motion\s*type: Anim\.FastSpatial/);

  for (const [file, owner, tail] of [
    ["QuickSettingChip.qml", "chip", "MarqueeText {"],
    ["OpacitySetting.qml", "setting", "ShellSlider {"],
    ["AdjustableSetting.qml", "setting", "ShellSlider {"],
  ]) {
    const source = read(file);
    const hintStart = source.indexOf("TileKeyHint {");
    assert.ok(
      hintStart > source.indexOf(tail),
      `${file}: keycap must not be nested in the content row`,
    );
    assert.equal((source.match(/TileKeyHint \{/g) || []).length, 1);
    const hint = source.slice(hintStart);
    assert.match(hint, new RegExp(`motion: ${owner}\\.motion`));
    assert.match(hint, /compact: true/);
    assert.doesNotMatch(
      hint,
      /verticalCenter: parent\.verticalCenter|topMargin:|rightMargin:/,
    );
  }
});
