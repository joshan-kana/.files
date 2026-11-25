const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const source = (name) => fs.readFileSync(path.join(root, "qml", name), "utf8");
const body = (qml, name) => {
  const match = qml.match(
    new RegExp(
      "    function " +
        name +
        "\\([^\\n]*?\\)\\s*:\\s*\\w+\\s*\\{([\\s\\S]*?)\\n    \\}",
    ),
  );
  assert.ok(match, name);
  return match[1];
};

test("shared confirmation arms on key-down, confirms once, cancels and expires", () => {
  const src = source("ConfirmationState.qml");
  const ctx = vm.createContext({
    pending: "",
    expiry: {
      restart() {
        this.armed = true;
      },
      stop() {
        this.armed = false;
      },
    },
  });
  vm.runInContext(
    "function request(action){" +
      body(src, "request") +
      "} function cancel(){" +
      body(src, "cancel") +
      "}",
    ctx,
  );
  assert.equal(ctx.request("poweroff"), false);
  assert.equal(ctx.pending, "poweroff");
  assert.equal(ctx.expiry.armed, true);
  assert.equal(ctx.request("poweroff"), true);
  assert.equal(ctx.pending, "");
  assert.equal(ctx.request("poweroff"), false);
  ctx.cancel();
  assert.equal(ctx.pending, "");
  assert.equal(ctx.expiry.armed, false);
  assert.equal(ctx.request(""), false);
  assert.match(src, /interval: guard.timeoutMs/);
  assert.match(src, /guard.expired\(\)/);
});

test("notifications retain records when history recording is disabled", () => {
  const src = source("NotificationState.qml");
  assert.match(
    src,
    /function toggleHistory\(\): void \{\s*settings.set\("historyEnabled", !historyEnabled\);/,
  );
  assert.doesNotMatch(
    body(src, "toggleHistory"),
    /clearAll|applyJournal|journal\s*=/,
  );
  assert.doesNotMatch(
    body(src, "setApplicationPreference"),
    /applyJournal|clearAll/,
  );
  assert.match(
    src,
    /managedApplications:[\s\S]*?Object.keys\(declared\)[\s\S]*?Object.keys\(overrides\)/,
  );
  assert.match(
    src,
    /typeof notification === "string" \? notification : NotificationSemantics.groupKey\(notification\)/,
  );
  assert.match(
    source("NotificationAppSettings.qml"),
    /model: panel.notificationState.managedApplications/,
  );
  assert.match(
    source("NotificationContent.qml"),
    /id: applicationSettingsAction/,
  );
});

test("Activity's app policies remain actionable without notification rows", () => {
  const ui = source("NotificationContent.qml");
  const editor = source("NotificationAppSettings.qml");
  assert.match(
    ui,
    /NotificationAppSettings \{[\s\S]*?visible: center.appSettingsOpen/,
  );
  assert.match(
    ui,
    /id: emptyState[\s\S]*?visible: center.groups.length === 0 && !center.appSettingsOpen/,
  );
  const policy = source("NotificationPolicy.js");
  for (const key of [
    "popups",
    "history",
    "silent",
    "criticalOnly",
    "privatePreview",
  ])
    assert.match(policy, new RegExp('key: "' + key + '"'));
  assert.match(editor, /model: Policy.applicationFields\(\)/);
  assert.match(
    editor,
    /setApplicationPreference\(entry.modelData.key, modelData.key, !active\)/,
  );
  assert.match(
    source("NotificationCard.qml"),
    /model: Policy.applicationFields\(\)/,
  );
  assert.match(editor, /resetApplicationPreferences\(entry.modelData.key\)/);
  assert.match(
    ui,
    /center.appSettingsOpen[\s\S]*?appSettings.move\(1\)[\s\S]*?appSettings.move\(-1\)/,
  );
});

test("notification pointer signals do not reference keyboard events they don't receive", () => {
  const ui = source("NotificationContent.qml");
  for (const signal of [
    "onActivated",
    "onDefaultRequested",
    "onReplyFocusRequested",
  ]) {
    const part = ui
      .split(signal + ": {")[1]
      .split("\n                            }")[0];
    assert.doesNotMatch(part, /event\./, signal);
  }
});

test("app history and global clear are separate, and clearing requires confirmation", () => {
  const ui = source("NotificationContent.qml");
  assert.match(
    ui,
    /function requestClearAll\(\): void \{\s*if \(!clearConfirmation.request\("all"\)\)\s*return;/,
  );
  assert.match(ui, /center.requestClearAll\(\)/);
  assert.match(
    ui,
    /center.clearConfirmation.pending[\s\S]*?center.requestClearAll\(\)/,
  );
  assert.match(ui, /History is off; popups may still appear/);
});

test("small tile hit targets paint hover and press feedback inside the existing keycap", () => {
  const quick = source("TileQuickAction.qml");
  assert.match(quick, /width: Math.max\(36, hint.implicitWidth/);
  assert.match(quick, /height: Math.max\(36, hint.implicitHeight/);
  assert.match(quick, /feedbackParent: action.hint/);
  assert.match(quick, /cornerRadius: Math.min\(9, action.hint.height \/ 3\)/);
  assert.match(quick, /hoverOpacity: 0.14/);
  assert.match(quick, /pressOpacity: 0.24/);
  assert.doesNotMatch(quick, /showHover: false|localFeedback/);
  for (const [name, expression] of [
    [
      "QuickSettingChip.qml",
      /emphasized: chip.active \|\| quickAction.pointerHovered \|\| quickAction.visualPressed/,
    ],
    [
      "ConnectivityTile.qml",
      /emphasized: tile.connected \|\| quickAction.pointerHovered \|\| quickAction.visualPressed/,
    ],
  ])
    assert.match(source(name), expression);
});

test("desktop scenes are owned by Visual Modes, not Power & Session", () => {
  const controls = source("SystemContent.qml");
  const session = source("SessionPanel.qml");
  const keybindings = fs.readFileSync(
    path.join(root, "keybindings.nix"),
    "utf8",
  );
  const visualModes = controls
    .split("id: visualTiles")[1]
    .split("id: mediaMatrix")[0];
  assert.match(visualModes, /QuickSettingChip \{/);
  assert.match(visualModes, /icon: DesktopIcons.glyphFor\("scenes"\)/);
  assert.match(visualModes, /detailActionId: "SystemContent.scenes"/);
  assert.match(visualModes, /detailName: "Desktop scenes"/);
  assert.match(visualModes, /onDetailsRequested: root.openSetting\("scenes"\)/);
  assert.doesNotMatch(
    visualModes
      .split('detailActionId: "SystemContent.scenes"')[1]
      .split("onDetailsRequested:")[0],
    /\bactionId:/,
  );
  assert.match(visualModes, /active: root.scenes.active/);
  assert.doesNotMatch(
    controls,
    /scenesButton|ShellAction \{[\s\S]*?id: scenesButton/,
  );
  const lookup = controls
    .split("function findDashboardAction(key: int, modifiers: int): var {")[1]
    .split("\n    }")[0];
  assert.doesNotMatch(lookup, /SystemContent.scenes|scenesButton/);
  assert.match(
    lookup,
    /for \(const section of \[controlsHeading, connectionTiles, actionTiles, visualTiles\]\)/,
  );
  assert.doesNotMatch(
    session,
    /scenesAction|scenesRequested|SessionPanel.scenes/,
  );
  assert.doesNotMatch(controls, /settingKind === "scenes"\)\s*openSession/);
  assert.match(keybindings, /"SystemContent.scenes" = "SHIFT\+L"/);
});

test("today's weather summary uses prominent existing forecast values", () => {
  const weather = source("WeatherContent.qml");
  const state = source("WeatherState.qml");
  assert.match(
    weather,
    /todayForecast: weather.forecast.length > 0 \? weather.forecast\[0\] : null/,
  );
  for (const key of ["low", "high", "rain"])
    assert.match(weather, new RegExp("panel\\.todayForecast\\." + key));
  assert.match(state, /precipitation_probability_max/);
  assert.match(weather, /text: "TODAY"/);
  assert.match(weather, /id: todayMetrics/);
  assert.match(weather, /font.pixelSize: panel.theme.fontSize\(21\)/);
  assert.match(weather, /Accessible.name: panel.weather.description/);
  assert.doesNotMatch(
    weather,
    /text: "Low " \+|text: "High " \+|text: "Rain " \+/,
  );
});

test("wallpaper and palette use one destination name and state-appropriate spectrum description", () => {
  const panel = source("WallpaperPanel.qml");
  const catalog = source("ActionCatalog.js");
  assert.match(panel, /title: "Wallpaper gallery"/);
  assert.match(catalog, /name: "Wallpaper Gallery"/);
  assert.match(catalog, /description: options.wallpaperSpectrumEnabled/);
  assert.match(source("SystemContent.qml"), /Wallpaper gallery/);
});

test("all destructive owners use the same expiry and cancellation controller", () => {
  for (const name of [
    "SessionPanel.qml",
    "SystemContent.qml",
    "NotificationContent.qml",
    "RecordingLibrary.qml",
    "BluetoothPanel.qml",
    "ClipboardPanel.qml",
  ])
    assert.match(source(name), /ConfirmationState \{/, name);
  assert.match(source("MediaLyrics.qml"), /printErrors: false/);
});

test("Restore Defaults requires Enter after arming; repeated clicks and shortcuts cannot confirm", () => {
  const controls = source("SystemContent.qml");
  const keybindings = fs.readFileSync(
    path.join(root, "keybindings.nix"),
    "utf8",
  );
  const resetTile = controls
    .split('title: root.resetRunning ? "Restoring…" : "Restore defaults"')[1]
    .split("ShellSurface {")[0];
  assert.match(resetTile, /if \(!root.resetConfirmPending\)/);
  assert.match(resetTile, /root.resetConfirmation.request\("desktop"\)/);
  assert.doesNotMatch(resetTile, /startDefaultReset/);
  const armedKeys = controls
    .split("if (root.resetConfirmPending) {")
    .at(-1)
    .split("const helpKey")[0];
  assert.match(
    armedKeys,
    /root.runtime.shellMatchesHint\("SystemContent.resetConfirm"/,
  );
  assert.doesNotMatch(
    armedKeys,
    /root.runtime.shellMatchesHint\("SystemContent.reset",/,
  );
  assert.match(keybindings, /"SystemContent.resetConfirm" = "ENTER"/);
});
