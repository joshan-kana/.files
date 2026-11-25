const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("the hub has one persistent Back action opposite contextual Help", () => {
  const tabs = qml("HubTabs.qml");
  const host = qml("ShellExpansionHost.qml");

  assert.match(tabs, /signal backRequested/);
  assert.match(tabs, /id: backButton[\s\S]*?anchors\.left: parent\.left/);
  assert.match(tabs, /id: helpButton[\s\S]*?anchors\.right: parent\.right/);
  assert.match(tabs, /track[\s\S]*?anchors\.left: backButton\.right/);
  assert.match(
    tabs,
    /Accessible\.name: root\.backLabel \+ " \(" \+ root\.runtime\.shellHint\("ShellExpansionHost.back"\) \+ "\)"/,
  );
  assert.match(tabs, /onActivated: root\.backRequested\(\)/);
  assert.match(host, /backLabel: host\.escapeHintLabel/);
  assert.match(host, /onBackRequested: host\.navigateBack\(\)/);
  assert.match(host, /function navigateBack\(\): void/);
  assert.match(host, /systemContent\.navigateBack\(\)/);
  assert.match(host, /activityContent\.navigateBack\(\)/);
  assert.match(host, /calendarContent\.navigateBack\(\)/);
  assert.match(host, /expansionState\.back\(\)/);

  // Help stays dismissible through Back; covered tab shortcuts cannot
  // activate controls behind the contextual help overlay.
  assert.match(host, /z: 250[\s\S]*?HubTabs|HubTabs \{[\s\S]*?z: 250/);
  assert.match(tabs, /disabled: root\.helpOpen/);
});

test("Escape and Back share the same Controls cancellation priorities", () => {
  const system = qml("SystemContent.qml");
  const keyHandler = system.indexOf("Keys.onPressed: event =>");
  const escapeHandler = system.indexOf(
    'if (event.key === root.runtime.shellKeyCode("controls", "Escape"))',
    keyHandler,
  );

  assert.ok(keyHandler !== -1 && escapeHandler > keyHandler);
  assert.match(
    system.slice(escapeHandler, escapeHandler + 220),
    /root\.navigateBack\(\)/,
  );
  assert.match(
    system,
    /if \(resetConfirmPending\)[\s\S]*?resetConfirmation.cancel\(\);/,
  );
  assert.match(system, /else if \(helpOpen\)[\s\S]*?helpOpen = false;/);
  assert.match(
    system,
    /else if \(themePanel\.open && themePanel\.panel && themePanel\.panel\.searching\)[\s\S]*?themePanel\.invoke\("leaveSearch"\)/,
  );
  assert.match(
    system,
    /else if \(wallpaperPanel\.open && wallpaperPanel\.panel && wallpaperPanel\.panel\.searching\)[\s\S]*?wallpaperPanel\.invoke\("leaveSearch"\)/,
  );
  assert.match(
    qml("ThemePanel.qml"),
    /function leaveSearch\(\): void \{\s*keyboardRequested\(\)/,
  );
  assert.match(
    qml("WallpaperPanel.qml"),
    /function leaveSearch\(\): void \{\s*panel\.keyboardRequested\(\)/,
  );
  assert.match(
    system,
    /else if \(mixerOpen\)[\s\S]*?handleKey\(Qt\.Key_Escape, Qt\.NoModifier\)/,
  );
  assert.match(
    system,
    /else if \(audioChooserOpen\)[\s\S]*?audioDeck\.handleKey\(Qt\.Key_Escape, Qt\.NoModifier\)/,
  );
  assert.match(
    system,
    /else if \(networkPanel\.open && networkPanel\.passwordPrompt\)[\s\S]*?cancelPassword/,
  );
  assert.match(
    system,
    /else if \(recordingsPanel\.open && recordingsPanel\.deletePending\.length > 0\)[\s\S]*?cancelDelete/,
  );
  assert.match(
    system,
    /else if \(sessionPanel\.open && sessionPanel\.armedAction\.length > 0\)[\s\S]*?cancelConfirmation/,
  );
  assert.match(
    system,
    /else if \(bluetoothPanel\.open && bluetoothPanel\.panel && bluetoothPanel\.panel\.forgetAddress\.length > 0\)[\s\S]*?clearTransientState/,
  );
  assert.match(
    system,
    /if \(bluetoothPanel\.open\)[\s\S]*?if \(event\.key === root\.runtime\.shellKeyCode\("controls", "Backspace"\)\) \{\s*root\.navigateBack\(\)/,
  );
  assert.match(
    system,
    /else if \(networkPanel\.open && networkPanel\.detailView\)[\s\S]*?toggleDetailView/,
  );
  assert.match(
    system,
    /else if \(networkPanel\.open && networkPanel\.savedView\)[\s\S]*?toggleSavedView/,
  );
  assert.match(
    system,
    /if \(networkPanel\.open\)[\s\S]*?if \(event\.key === root\.runtime\.shellKeyCode\("controls", "Backspace"\)\) \{\s*root\.navigateBack\(\)/,
  );
  assert.match(system, /else if \(trayMenu\.open\)[\s\S]*?goBack/);
  assert.match(
    system,
    /else if \(!detailsVisible && selectedSlider\.length > 0\)[\s\S]*?selectedSlider = ""/,
  );
  assert.match(system, /else if \(detailsVisible\)[\s\S]*?backFromDetail\(\)/);
});

test("Back cancels the Home calendar picker and inline Activity reply locally", () => {
  const calendar = qml("CalendarContent.qml");
  const activity = qml("NotificationContent.qml");

  assert.match(
    calendar,
    /function navigateBack\(\): void \{\s*if \(calendarPickerOpen\) \{\s*calendarPickerOpen = false;/,
  );
  assert.match(calendar, /calendar\.navigateBack\(\)/);
  assert.match(
    activity,
    /function navigateBack\(\): void \{[\s\S]*?else if \(replyEditing\) \{\s*replyOwner = null;\s*replyEditing = false;\s*focusKeyboard\(\)/,
  );
  assert.match(activity, /center\.navigateBack\(\)/);
});

test("Activity Escape collapses nested notification groups before closing", () => {
  const activity = qml("NotificationContent.qml");
  const back = activity
    .split("function navigateBack(): void {")[1]
    .split("\n    }")[0];
  assert.match(back, /if \(replyEditing\)[\s\S]*?focusKeyboard\(\)/);
  assert.match(
    back,
    /else if \(expandedGroupKey\.length > 0\) \{\s*expandedGroupKey = "";\s*selectedMemberIndex = 0;\s*focusKeyboard\(\)/,
  );
  assert.match(back, /else \{\s*closeRequested\(\);/);
  assert.match(activity, /Keys\.onPressed:[\s\S]*?center\.navigateBack\(\)/);
});

test("focused setting details share the hub Back/Escape history", () => {
  const system = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  const history = qml("ShellExpansionState.qml");

  assert.match(
    system,
    /readonly property bool settingsOpen: settingsPanel\.open/,
  );
  assert.match(system, /readonly property bool vhsOpen: vhsPanel\.open/);
  assert.match(
    host,
    /readonly property bool detailVisible:[^\n]*systemContent\.settingsOpen \|\| systemContent\.vhsOpen/,
  );
  assert.match(system, /function openSetting\(name: string\): void \{/);
  assert.match(system, /settingsPanel\.openView\(\);\s*markDetail\(name\);/);
  assert.match(
    system,
    /function navigateBack\(\): void \{[\s\S]*?else if \(detailsVisible\) \{\s*backFromDetail\(\)/,
  );
  assert.match(
    history,
    /function enterDetail\(view: string\): void \{[\s\S]*?backDestination = fromControls \? "controls" : ""/,
  );
  assert.match(
    history,
    /function back\(\): void \{[\s\S]*?currentView = destination === "controls" \? "controls" : ""/,
  );
});

test("one-shot detail actions execute on initial key-down without auto-repeat", () => {
  const system = qml("SystemContent.qml");
  const detail = qml("SettingsDetail.qml");
  const stateLayer = qml("StateLayer.qml");

  assert.match(system, /Keys\.onPressed: event => \{/);
  assert.match(
    system,
    /if \(dashboardAction && event\.isAutoRepeat\) \{\s*event.accepted = true;\s*return;/,
  );
  assert.match(
    system,
    /settingsPanel\.invoke\("handleKey", event\.key, event\.modifiers, event\.isAutoRepeat\)/,
  );
  assert.match(
    detail,
    /function handleKey\(key: int, modifiers: int, autoRepeat: bool\): bool \{/,
  );
  assert.match(detail, /if \(autoRepeat\) \{[\s\S]*?SettingsDetail\.toggle/);
  assert.match(
    detail,
    /runtime\.shellChoiceIndex\(key, modifiers, choiceCount\)/,
  );
  assert.match(
    stateLayer,
    /Keys\.onPressed: event => \{[\s\S]*?if \(!event\.isAutoRepeat\) \{[\s\S]*?playPressFeedback\([\s\S]*?activated\(event\)/,
  );
});

test("Weather Back and Escape discard the same location draft before leaving the page", () => {
  const weather = qml("WeatherContent.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(
    host,
    /else if \(weatherContent\) \{\s*weatherContent.navigateBack\(\)/,
  );
  assert.match(
    weather,
    /function navigateBack\(\): void \{\s*if \(locationEditing\)\s*finishLocation\(false\);\s*else\s*closeRequested\(\)/,
  );
  assert.equal(
    [
      ...weather.matchAll(
        /shellKeyCode\("weather", "Escape"\)\) \{\s*if \(!event.isAutoRepeat\)\s*panel.navigateBack\(\)/g,
      ),
    ].length,
    2,
  );
  assert.match(
    host,
    /tabShortcutsEnabled: [^\n]*!\(weatherContent && weatherContent.locationEditing\)/,
  );
  assert.match(
    host,
    /escapeHintLabel: [^\n]*weatherContent.locationEditing[^\n]*"Exit search"/,
  );
});

test("Escape autorepeat is consumed before nested navigation can change focus again", () => {
  const repeated = [
    ["NotificationContent.qml", "center", "activity", 1],
    ["CalendarContent.qml", "calendar", "calendar", 1],
    ["OverviewPanel.qml", "overview", "overview", 1],
    ["ScreenshotPicker.qml", "picker", "capture", 1],
    ["ShortcutCheatsheet.qml", "window", "help", 1],
    ["MediaContent.qml", "content", "media", 1],
    ["ClipboardPanel.qml", "panel", "clipboard", 2],
  ];
  for (const [file, owner, scope, count] of repeated) {
    const guard = `if (event.isAutoRepeat && event.key === ${owner}.runtime.shellKeyCode("${scope}", "Escape")) {`;
    const source = qml(file);
    const blocks = source.split(guard).slice(1);
    assert.equal(blocks.length, count, file);
    for (const block of blocks)
      assert.match(block, /^\s*event\.accepted = true;\s*return;\s*\}/, file);
  }
  for (const [file, count] of [
    ["SystemContent.qml", 1],
    ["NetworkPanel.qml", 2],
    ["BluetoothPanel.qml", 1],
    ["ScenePanel.qml", 1],
    ["WallpaperPanel.qml", 1],
    ["ThemePanel.qml", 1],
    ["NotificationCard.qml", 1],
    ["PolkitDialog.qml", 1],
    ["WeatherContent.qml", 2],
  ]) {
    const guarded = qml(file).matchAll(
      /shellKeyCode\("[^"]+", "Escape"\)\) \{\s*if \(!event\.isAutoRepeat\)\s*[^;]+;\s*event\.accepted = true;/g,
    );
    assert.equal([...guarded].length, count, file);
  }
  for (const [file, scope] of [
    ["AudioMixerContent.qml", "mixer"],
    ["DisplaySettings.qml", "controls"],
  ])
    assert.ok(
      qml(file).includes(
        `if (autoRepeat && key === runtime.shellKeyCode("${scope}", "Escape"))\n            return true;`,
      ),
      file,
    );
  assert.match(
    qml("RecordingLibrary.qml"),
    /Keys\.onEscapePressed: event => \{\s*if \(!event\.isAutoRepeat\) \{[\s\S]*?\}\s*event\.accepted = true;/,
  );
  for (const [file, action] of [
    ["ShellExpansionHost.qml", "ShellExpansionHost.closeAll"],
    ["CommandPalette.qml", "CommandPalette.closeAll"],
  ])
    assert.ok(
      qml(file).includes(
        `shellSequence("${action}")\n        autoRepeat: false`,
      ),
      file,
    );
});

test("palette consumes repeated Escape in both search and results focus", () => {
  const src = qml("CommandPalette.qml");
  assert.equal(
    [
      ...src.matchAll(
        /shellKeyCode\("palette", "Escape"\)\) \{\s*if \(!event\.isAutoRepeat\)\s*palette\.dismissOrReset\(\);/g,
      ),
    ].length,
    2,
  );
});
