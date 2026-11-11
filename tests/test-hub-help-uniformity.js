const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("a single shared question-mark action is visible on every hub page and detail", () => {
  const tabs = qml("HubTabs.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(tabs, /signal helpRequested/);
  assert.match(tabs, /shortcut: "\?"/);
  assert.match(tabs, /Accessible\.name: "Keyboard help"/);
  assert.match(tabs, /onActivated: root\.helpRequested\(\)/);
  assert.match(host, /helpOpen: host\.helpVisible/);
  assert.match(host, /onHelpRequested: host\.toggleHelp\(\)/);
  assert.match(
    host,
    /readonly property var helpKeys: systemContent \? systemContent\.helpBindings : mediaContent \? mediaContent\.helpBindings : otherHelpKeys/,
  );
  assert.match(
    host,
    /readonly property string helpCaption:.*Activity controls.*Weather controls.*Home controls/,
  );
  assert.doesNotMatch(
    qml("SystemContent.qml"),
    /id: helpButton|title: "Help \(\?\)"/,
  );
  assert.doesNotMatch(
    qml("MediaContent.qml"),
    /label: "Help"|title: "Help \(\?\)"/,
  );
});

test("contextual help can be opened and dismissed on every hub page without triggering underlying shortcuts", () => {
  const host = qml("ShellExpansionHost.qml");
  assert.match(host, /function toggleHelp\(\): void/);
  assert.match(host, /sequence: "\?"[\s\S]*?onActivated: host\.toggleHelp\(\)/);
  assert.match(
    host,
    /sequence: "Esc"[\s\S]*?onActivated: host\.otherHelpOpen = false/,
  );
  assert.match(host, /enabled: !host\.otherHelpOpen/);
  assert.match(host, /onCurrentComponentChanged: \{\s*otherHelpOpen = false;/);
  assert.match(host, /else\s+host\.otherHelpOpen = false;/);
  assert.match(host, /sequence: "J"[\s\S]*?scopedHelp\.scrollHints\(1\)/);
  assert.match(host, /sequence: "K"[\s\S]*?scopedHelp\.scrollHints\(-1\)/);
});
