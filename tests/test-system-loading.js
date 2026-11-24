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
    /Array\.from\(viewStack\.children\)\.find\(source => source\.exposed === true && source\.foregroundBusy === true\)/,
  );
  assert.match(
    controls,
    /foregroundBusy: !!foregroundSource \|\| \(mixerOpen && audioDeck\.foregroundBusy\)/,
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
    /operationOwner: loadedContent && loadedContent\.foregroundBusy === true \? loadedContent : null/,
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

test("background operations show only on their owning visible dashboard tiles", () => {
  const controls = source("SystemContent.qml");
  assert.match(
    controls,
    /dashboardExposed: presentationActive && engaged && !detailsVisible/,
  );
  for (const owner of [
    "themePanel.foregroundBusy",
    "wallpaperPanel.foregroundBusy",
    "networkPanel.foregroundBusy",
    "bluetoothPanel.foregroundBusy",
    "recordingsPanel.foregroundBusy",
    "root.displayBusy",
    "root.resetRunning",
    "root.nightLightBusy",
  ]) {
    assert.ok(
      controls.includes("foregroundBusy: root.dashboardExposed && " + owner),
      owner,
    );
  }
  assert.match(controls, /destinationBusy: mixerView.foregroundBusy/);
  assert.match(
    source("SettingsDetail.qml"),
    /displayOperationBusy: displayDetails.foregroundBusy/,
  );
  assert.match(
    source("SettingsDetail.qml"),
    /foregroundBusy: kind === "displays" \? displayOperationBusy : kind === "nightLight" && nightLight.foregroundBusy/,
  );
  assert.match(
    source("WeatherSummary.qml"),
    /foregroundBusy: summary.presentationActive && summary.weather.loading && summary.weather.foregroundLoading/,
  );
  const surface = source("ShellSurface.qml");
  assert.match(surface, /active: root.visible && root.foregroundBusy/);
  assert.match(
    surface,
    /LoadingOutline \{[\s\S]*?surface: root[\s\S]*?motion: root\.motion/,
  );
  assert.match(
    source("LoadingOutline.qml"),
    /active: outline.active && !outline.motionEnabled/,
  );
  for (const [name, owner] of [
    ["ShellAction.qml", "root"],
    ["QuickSettingChip.qml", "chip"],
    ["ConnectivityTile.qml", "tile"],
  ]) {
    assert.ok(
      source(name).includes("foregroundBusy: " + owner + ".foregroundBusy"),
      name,
    );
  }
});

test("navigation cannot clear ongoing operation state", () => {
  const network = source("NetworkPanel.qml");
  assert.match(
    network,
    /foregroundBusy: .*detailPending \|\| networks.some\(network => network.stateChanging\)/,
  );
  const recording = source("RecordingLibrary.qml");
  for (const name of ["openView", "closeView"]) {
    const body = recording
      .split("function " + name + "(): void {")[1]
      .split("\n    }")[0];
    assert.doesNotMatch(
      body,
      /editorRequestRunning = false|editorRequestTimeout.stop/,
    );
  }
  assert.match(
    source("NightLightState.qml"),
    /foregroundBusy: busy \|\| queuedTemperature >= 0/,
  );
});
