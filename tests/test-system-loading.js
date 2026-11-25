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
  assert.match(frame, /active: output\.exposed && output\.busyHere/);
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
    source("BusyContour.qml"),
    /active: trace.active && !trace.motion.enabled/,
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
    /foregroundBusy: busy \|\| resetPending \|\| resetting \|\| queuedTemperature >= 0/,
  );
});

test("global and detail reset share the serialized Night Light reset operation", () => {
  const state = source("NightLightState.qml");
  const controls = source("SystemContent.qml");
  const actions = source("Actions.qml");
  const detail = source("SettingsDetail.qml");
  assert.match(
    state,
    /function resetToDeclared\(\): void \{\s*temperatureDebounce.stop\(\);\s*queuedTemperature = -1;\s*queuedSchedule = \{\}/,
  );
  assert.match(state, /if \(root.resetPending\) \{\s*root.applyReset\(\)/);
  assert.match(
    state,
    /actionProcess.exec\(\[runtime.nightLightControl, "reset"\]\)/,
  );
  assert.match(
    actions,
    /waitingForNightLightReset = true;\s*resetDeadline.restart\(\);\s*nightLightState.resetToDeclared\(\)/,
  );
  assert.match(actions, /function onResetFinished\(success, reason\)/);
  assert.match(controls, /shellActions\.restoreDesktopDefaults\(\)/);
  assert.doesNotMatch(
    controls,
    /property var resetSteps|sessionPanel\.invoke\("resetToDeclared"/,
  );
  assert.match(detail, /nightLight.resetToDeclared\(\)/);
});

test("desktop reset completes independently of the Controls view and reports backend failures", () => {
  const vm = require("node:vm");
  const code = source("Actions.qml");
  const body = (signature) => code.split(signature)[1].split("\n    }")[0];
  const calls = [];
  const record = (name) => () => calls.push(name);
  const context = vm.createContext({
    resetRunning: false,
    resetStatus: "",
    resetSteps: [],
    resetErrors: [],
    resetIndex: 0,
    waitingForNightLightReset: false,
    resetTimedOut: false,
    resetDeadline: { restart: () => {}, stop: () => {} },
    scenes: { stop: record("scene") },
    appearance: {
      resetToDeclared: record("appearance"),
      resetOperations: () => [{ label: "Blur", command: ["hyprctl", "blur"] }],
    },
    motion: {
      resetToDeclared: record("motion"),
      resetOperations: () => [
        { label: "Motion", command: ["hyprctl", "motion"] },
      ],
    },
    capture: { resetToDeclared: record("capture") },
    weather: {
      resetLocation: record("weather location"),
      resetUnits: record("weather units"),
    },
    systemState: { resetSessionPreferences: record("session") },
    notificationState: { resetToDeclared: record("notifications") },
    resources: { resetSampling: record("resources") },
    nightLightState: { resetToDeclared: record("night light") },
    runtime: {
      hyprctl: "hyprctl",
      vhsControl: "vhs",
      captureLocations: "capture",
      wallpaperLibrary: "wallpaper",
      wallpaperPolicy: "schedule",
      nightLightControl: "night",
    },
    Quickshell: { screens: [{ name: "Virtual-1" }] },
    preferenceReset: {
      exec: (command) => calls.push(Array.from(command).join(" ")),
    },
  });
  vm.runInContext(
    "function restoreDesktopDefaults() {" +
      body("function restoreDesktopDefaults(): void {") +
      "}\nfunction resetNextPreference() {" +
      body("function resetNextPreference(): void {") +
      "}",
    context,
  );
  context.restoreDesktopDefaults();
  assert.equal(context.resetRunning, true);
  assert.equal(context.waitingForNightLightReset, true);
  assert.deepEqual(calls, [
    "scene",
    "appearance",
    "motion",
    "capture",
    "weather location",
    "weather units",
    "session",
    "notifications",
    "resources",
    "night light",
  ]);
  context.restoreDesktopDefaults();
  assert.equal(calls.length, 10);
  context.waitingForNightLightReset = false;
  context.resetErrors.push("Night Light");
  context.resetNextPreference();
  while (context.resetRunning) {
    context.resetIndex++;
    context.resetNextPreference();
  }
  assert.deepEqual(calls.slice(10), [
    "hyprctl blur",
    "hyprctl motion",
    "capture reset",
    "wallpaper reset Virtual-1",
    "wallpaper reset all",
    "schedule reset",
  ]);
  assert.match(context.resetStatus, /Could not restore: Night Light/);
  assert.equal(context.resetRunning, false);
  assert.doesNotMatch(
    source("SessionPanel.qml"),
    /PreferenceStore|function resetToDeclared/,
  );
  assert.match(
    source("SessionPanel.qml"),
    /panel.system.resetSessionPreferences/,
  );
});

test("reset verifies compositor command replies and authoritative option readback", () => {
  const code = source("Actions.qml");
  const body = code
    .split(
      "function resetStepSucceeded(step: var, code: int, output: string): bool {",
    )[1]
    .split("\n    }")[0];
  const check = new Function("step", "code", "output", body);
  assert.equal(check({ expectedText: "ok" }, 0, "ok\n"), true);
  assert.equal(check({ expectedText: "ok" }, 0, "error"), false);
  assert.equal(
    check({ expectedField: "bool", expectedValue: false }, 0, '{"bool":false}'),
    true,
  );
  assert.equal(
    check({ expectedField: "bool", expectedValue: false }, 0, '{"bool":true}'),
    false,
  );
  assert.equal(
    check({ expectedField: "int", expectedValue: 17 }, 0, '{"int":12}'),
    false,
  );
  assert.equal(
    check({ expectedField: "float", expectedValue: 0.8 }, 0, '{"float":0.8}'),
    true,
  );
  assert.equal(
    check({ expectedField: "int", expectedValue: 17 }, 0, "unknown option"),
    false,
  );
  assert.equal(check({}, 1, "ok"), false);
});
