const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );
test("root tray Escape returns to Controls without dismissing the entire hub", () => {
  const src = qml("SystemContent.qml");
  assert.match(
    src,
    /if \(trayMenu\.open\) \{[\s\S]*?trayMenu\.panel\.stack\.length <= 1\) \{/,
  );
  assert.match(
    src,
    /trayMenu\.closeMenu\(\);\s*if \(root\.requestedView\.startsWith\("tray:"\)\)\s*root\.detailRequested\("controls"\);\s*keyboardFocus\.forceActiveFocus\(\)/,
  );
  assert.match(src, /else \{\s*trayMenu\.invoke\("goBack"\);\s*\}/);
  assert.match(src, /event\.accepted = true;/);
  const tray = qml("TrayMenuView.qml");
  assert.match(
    tray,
    /function goBack\(\): void \{[\s\S]*?if \(stack\.length <= 1\)/,
  );
});
test("Shift+Esc remains the global close-all command", () => {
  assert.match(
    qml("ShellExpansionHost.qml"),
    /sequence: "Shift\+Esc"[\s\S]*?onActivated: host\.expansionState\.close\(\)/,
  );
});

test("tray keyboard selection uses one persistent highlight rather than swapping tile surfaces", () => {
  const controls = qml("SystemContent.qml");
  const start = controls.indexOf("id: trayChoices");
  const end = controls.indexOf("KeyHintStrip {", start);
  assert.ok(start >= 0 && end > start);
  const tray = controls.slice(start, end);
  assert.match(tray, /id: traySelection/);
  assert.match(tray, /root.trayIndex/);
  assert.match(tray, /Behavior on x/);
  assert.match(tray, /model: root.system.trayItems/);
  assert.match(tray, /selected: false/);
  assert.doesNotMatch(tray, /selected: index === root.trayIndex/);
});
