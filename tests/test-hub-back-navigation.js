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
  assert.match(tabs, /Accessible\.name: root\.backLabel \+ " \(Esc\)"/);
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
    "if (event.key === Qt.Key_Escape)",
    keyHandler,
  );

  assert.ok(keyHandler !== -1 && escapeHandler > keyHandler);
  assert.match(
    system.slice(escapeHandler, escapeHandler + 155),
    /root\.navigateBack\(\)/,
  );
  assert.match(
    system,
    /if \(resetConfirmPending\)[\s\S]*?resetConfirmPending = false;/,
  );
  assert.match(system, /else if \(helpOpen\)[\s\S]*?helpOpen = false;/);
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
    /else if \(networkPanel\.open && networkPanel\.detailView\)[\s\S]*?toggleDetailView/,
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
    /function navigateBack\(\): void \{\s*if \(replyEditing\) \{\s*replyOwner = null;\s*replyEditing = false;\s*focusKeyboard\(\)/,
  );
  assert.match(activity, /center\.navigateBack\(\)/);
});
