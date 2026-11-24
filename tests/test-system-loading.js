const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const source = (name) =>
  fs.readFileSync(
    path.join(__dirname, `../modules/desktop/hyprland/shell/qml/${name}`),
    "utf8",
  );

test("busy views participate in the shared outline by default, with explicit passive-read exclusions", () => {
  const details = source("DeferredDetail.qml");
  const controls = source("SystemContent.qml");
  assert.match(
    details,
    /panel\.foregroundBusy !== undefined \? !!panel\.foregroundBusy : !!\(panel\.busy \|\| panel\.operationRunning\)/,
  );
  assert.match(
    controls,
    /Array\.from\(viewStack\.children\)\.find\(source => source\.foregroundBusy === true\)/,
  );
  assert.match(
    controls,
    /foregroundBusy: resetRunning \|\| nightLight\.busy \|\| audioDeck\.foregroundBusy \|\| !!foregroundSource/,
  );
  assert.match(
    source("DisplaySettings.qml"),
    /foregroundBusy: busy && activeCommand !== "status"/,
  );
  assert.match(
    source("WallpaperPanel.qml"),
    /foregroundBusy: busy \|\| \(policyBusy && activePolicyCommand !== "status"\)/,
  );
  assert.match(
    source("RecordingLibrary.qml"),
    /foregroundBusy: editorRequestRunning \|\| actionProcess\.running \|\| ocrProcess\.running \|\| \(locationProcess\.running && locationCommand !== "status"\)/,
  );
  assert.match(
    source("AudioMixerContent.qml"),
    /foregroundBusy: .*effectsState\.awaitingConfirmation \|\| effectsState\.requestedPreset !== null/,
  );
  assert.match(
    source("NetworkPanel.qml"),
    /foregroundBusy: profileAction\.running \|\| editApply\.running/,
  );
  assert.match(
    source("WeatherContent.qml"),
    /foregroundBusy: weather\.loading && weather\.foregroundLoading/,
  );
});

test("frame and floating hub share one busy-state source and semantic colour", () => {
  const host = source("ShellExpansionHost.qml");
  const shell = source("shell.qml");
  const frame = source("DesktopFrame.qml");
  assert.match(
    host,
    /loadingOperationVisible: expansionState\.hasCurrent && !!operationOwner/,
  );
  assert.match(
    host,
    /\.find\(owner => owner && owner\.foregroundBusy === true\)/,
  );
  assert.match(
    host,
    /active: !host\.frameVisible && host\.loadingOperationVisible/,
  );
  assert.match(host, /highlightColor: host\.loadingOperationColor/);
  assert.match(shell, /busy: !!expansionHost\.loadingOperationVisible/);
  assert.match(shell, /busyColor: expansionHost\.loadingOperationColor/);
  assert.match(shell, /busyScreen: qmlExpansionState\.screen/);
  assert.match(frame, /highlightColor: frame\.busyColor/);
  assert.match(
    frame,
    /active: output\.exposed && output\.busyHere && !frame\.motion\.enabled/,
  );
});
