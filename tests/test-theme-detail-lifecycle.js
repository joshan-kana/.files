const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, `../modules/desktop/hyprland/shell/qml/${name}`),
    "utf8",
  );

test("closed theme details cannot steal focus while the hub is closing", () => {
  const source = qml("ThemePanel.qml");
  const close = source.match(
    /function closeView\(\): void \{([\s\S]*?)\n    \}/,
  )?.[1];
  assert.ok(close);
  assert.match(close, /if \(!open\)\s*return/);
  assert.match(close, /open = false/);
  assert.doesNotMatch(close, /keyboardRequested\(/);
});

test("Controls restores detail focus only while engaged", () => {
  const source = qml("SystemContent.qml");
  assert.match(
    source,
    /function applyRequestedView\(\): void \{\s*if \(!engaged\)\s*return;/,
  );
  assert.match(
    source,
    /const leavingDetail = detailsVisible;\s*closeDetails\(\);\s*if \(leavingDetail\)\s*keyboardFocus\.forceActiveFocus\(\)/,
  );
});

test("a stale queued expansion cannot reopen a closing or replaced hub", () => {
  const source = qml("ShellExpansionHost.qml");
  assert.match(source, /property int transitionEpoch: 0/);
  assert.match(source, /const epoch = \+\+host\.transitionEpoch/);
  assert.match(
    source,
    /if \(host\.transitionEpoch === epoch && host\.expansionState\.hasCurrent\)\s*host\.contentExpanded = true/,
  );
});
