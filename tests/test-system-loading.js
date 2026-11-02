const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const source = (name) =>
  fs.readFileSync(
    path.join(__dirname, `../modules/desktop/hyprland/shell/qml/${name}`),
    "utf8",
  );

test("shared Controls loading tracks slow explicit actions, not passive polling", () => {
  const details = source("DeferredDetail.qml");
  const controls = source("SystemContent.qml");
  assert.match(
    details,
    /profileActionRunning: !!\(panel && panel\.profileAction && panel\.profileAction\.running\)/,
  );
  assert.match(
    details,
    /captureTrashRunning: !!\(panel && panel\.actionProcess && panel\.actionProcess\.running\)/,
  );
  assert.match(
    controls,
    /maintenanceOperationRunning: resetRunning \|\| \(networkPanel\.open && networkPanel\.profileActionRunning\) \|\| \(recordingsPanel\.open && recordingsPanel\.captureTrashRunning\)/,
  );
  assert.match(
    controls,
    /maintenanceOperationRole: recordingsPanel\.open && recordingsPanel\.captureTrashRunning \? "capture" : networkPanel\.open && networkPanel\.profileActionRunning \? "connectivity" : ""/,
  );
  assert.doesNotMatch(
    controls,
    /maintenanceOperationRunning:.*(weather|agenda|scannerEnabled|profilesQuery|listProcess)/,
  );
});

test("connected frame and floating Controls share one busy-state source", () => {
  const host = source("ShellExpansionHost.qml");
  const shell = source("shell.qml");
  assert.match(
    host,
    /loadingOperationVisible: themeOperationVisible \|\| wallpaperOperationVisible \|\| captureEditorRequestVisible \|\| maintenanceOperationVisible/,
  );
  assert.match(
    host,
    /active: !host\.frameVisible && host\.loadingOperationVisible/,
  );
  assert.match(host, /maintenanceOperationRole/);
  assert.match(shell, /busy: expansionHost\.loadingOperationVisible/);
  assert.match(shell, /busyScreen: expansionState\.screen/);
});
