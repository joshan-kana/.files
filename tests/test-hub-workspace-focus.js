const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const host = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
  ),
  "utf8",
);

test("workspace changes rearm the compositor keyboard grab for all hub views", () => {
  assert.match(
    host,
    /target: Hyprland[\s\S]*?function onFocusedWorkspaceChanged\(\): void \{\s*host\.restoreKeyboardAfterWorkspace\(\)/,
  );
  assert.match(host, /restoringWorkspaceFocus = true/);
  assert.match(
    host,
    /active: host\.expansionState\.hasCurrent && host\.backingWindowVisible && !host\.themeTerminalActive && !host\.restoringWorkspaceFocus/,
  );
  assert.match(host, /host\.loadedContent\.forceActiveFocus\(\)/);
  assert.match(host, /id: workspaceFocusRestart[\s\S]*?interval: 35/);
  assert.match(host, /id: focusGrabLost[\s\S]*?interval: 170/);
});

test("genuine focus losses still close, but workspace focus round-trip cannot", () => {
  assert.match(
    host,
    /if \(!host\.themeTerminalActive && !host\.restoringWorkspaceFocus\)\s*focusGrabLost\.restart\(\)/,
  );
  assert.match(
    host,
    /if \(!host\.expansionState\.hasCurrent\) \{\s*workspaceFocusRestart\.stop\(\);\s*focusGrabLost\.stop\(\);/,
  );
  assert.match(
    host,
    /focusGrabLost\.stop\(\);\s*restoringWorkspaceFocus = true/,
  );
  assert.match(
    host,
    /if \(!host\.expansionState\.hasCurrent \|\| host\.themeTerminalActive\)/,
  );
});

test("bar and frame visibility transitions rearm the same compositor keyboard grab", () => {
  assert.match(host, /onBarVisibleChanged: restoreKeyboardAfterWorkspace\(\)/);
  assert.match(
    host,
    /onFrameVisibleChanged: restoreKeyboardAfterWorkspace\(\)/,
  );
  assert.match(
    host,
    /focusGrabLost.stop\(\);\s*restoringWorkspaceFocus = true/,
  );
  assert.match(host, /host.loadedContent.forceActiveFocus\(\)/);
});
