const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = (name) => fs.readFileSync(path.join(root, "qml", name), "utf8");
const shellHints = JSON.parse(
  execFileSync(
    "nix",
    [
      "eval",
      "--impure",
      "--json",
      "--expr",
      "import ./modules/desktop/hyprland/shell/keybindings.nix",
    ],
    { cwd: path.join(__dirname, ".."), encoding: "utf8" },
  ),
).hints;

test("shared blur has one Nix baseline and one runtime override in both detail panels", () => {
  const settings = qml("AppearancePreferences.qml");
  const controls = qml("SystemContent.qml");
  const detail = qml("SettingsDetail.qml");
  const runtime = qml("RuntimeConfig.qml");
  const nix = fs.readFileSync(path.join(root, "default.nix"), "utf8");

  assert.doesNotMatch(
    nix,
    /blurEnabled = lib\.mkOption|blurSize = lib\.mkOption/,
  );
  assert.match(
    nix,
    /blurEnabled = config\.wayland\.windowManager\.hyprland\.settings\.config\.decoration\.blur\.enabled;/,
  );
  assert.match(
    nix,
    /blurSize = config\.wayland\.windowManager\.hyprland\.settings\.config\.decoration\.blur\.size;/,
  );
  assert.match(runtime, /appearanceDefaults: root\.configData\.appearance/);
  assert.doesNotMatch(runtime, /property (?:bool blurEnabled|int blurSize):/);
  assert.match(
    settings,
    /readonly property bool blurEnabled: effective\("blurEnabled"\)/,
  );
  assert.match(
    settings,
    /readonly property int blurSize: .*effective\("blurSize"\)/,
  );
  assert.match(settings, /function toggleBlur\(\): void/);
  assert.match(settings, /function clearOverride\(key: string\): void/);
  assert.match(settings, /enabled = " \+ \(blurEnabled \? "true" : "false"\)/);
  assert.match(
    settings,
    /property Timer blurSizeApply: Timer \{\s*interval: 75/,
  );
  assert.match(detail, /hasBlur: \["windows", "glass"\]\.includes\(kind\)/);
  assert.match(detail, /key: "blurSize"/);
  assert.match(detail, /onActivated: panel\.appearance\.toggleBlur\(\)/);
  assert.match(detail, /appearance\.clearOverride\("blurEnabled"\)/);
  assert.match(controls, /onDetailsRequested: root\.openSetting\("windows"\)/);
  assert.match(controls, /onDetailsRequested: root\.openSetting\("glass"\)/);
  assert.doesNotMatch(controls, /OpacitySetting \{|AdjustableSetting \{/);
});

test("split tile hit targets keep quick and detail actions independently keyboard accessible", () => {
  const quick = qml("TileQuickAction.qml");
  const connectivity = qml("ConnectivityTile.qml");
  const chip = qml("QuickSettingChip.qml");
  const controls = qml("SystemContent.qml");
  assert.match(quick, /anchors \{[\s\S]*?left: parent\.left/);
  assert.match(quick, /actionName: "Toggle"/);
  assert.match(connectivity, /onActivated: tile\.detailsRequested\(\)/);
  assert.match(
    connectivity,
    /TileQuickAction \{[\s\S]*?onActivated: tile\.activated\(\)/,
  );
  assert.match(
    chip,
    /onActivated: chip\.hasDetails \? chip\.detailsRequested\(\) : chip\.activated\(\)/,
  );
  assert.match(
    chip,
    /TileQuickAction \{[\s\S]*?onActivated: chip\.activated\(\)/,
  );
  for (const key of [
    "windowsDetails",
    "glassDetails",
    "nightLightDetails",
    "alertsDetails",
    "stayDetails",
    "powerDetails",
  ]) {
    assert.match(
      controls,
      new RegExp('detailActionId: "SystemContent\\.' + key),
    );
  }
});

test("compact Visual Modes tiles have no embedded parameter sliders", () => {
  const controls = qml("SystemContent.qml");
  const visuals = controls.slice(
    controls.indexOf("id: visualTiles"),
    controls.indexOf("id: mediaMatrix"),
  );
  assert.doesNotMatch(
    visuals,
    /ShellSlider \{|OpacitySetting \{|AdjustableSetting \{/,
  );
  assert.match(
    controls,
    /readonly property var sliderTargets: brightness\.supported \? \["brightness"\] : \[\]/,
  );
  assert.match(qml("SettingsDetail.qml"), /ParameterCard \{/);
  assert.match(qml("ParameterCard.qml"), /ShellSlider \{/);
});

test("visual parameter controls do not add a separate appearance action row", () => {
  const controls = qml("SystemContent.qml");
  const settings = qml("AppearancePreferences.qml");
  assert.doesNotMatch(
    controls,
    /Undo appearance|Choose a visual setting|selectedAppearanceKey|resetSelectedAppearance/,
  );
  assert.doesNotMatch(
    settings,
    /lastAppearanceChange|beginAdjustment|undoLastChange/,
  );
  assert.equal(shellHints["SystemContent.undoAppearance"], undefined);
  assert.equal(shellHints["SystemContent.resetSetting"], undefined);
  assert.doesNotMatch(controls, /opacitySettingsButton|openTransparency/);
});

test("status is a Controls detail with shared data and nested Escape", () => {
  const controls = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  const shell = qml("shell.qml");
  assert.match(
    controls,
    /title: "Status"[\s\S]*?onDetailsRequested: root\.openStatus\(\)/,
  );
  assert.match(controls, /function openStatus\(\): void/);
  assert.match(controls, /StatusContent \{[\s\S]*?keyboard: root\.keyboard/);
  assert.doesNotMatch(
    controls.slice(
      controls.indexOf("StatusContent {"),
      controls.indexOf("DeferredDetail {", controls.indexOf("StatusContent {")),
    ),
    /onCloseRequested: root\.backFromDetail\(\)/,
  );
  assert.match(host, /systemContent\.detailsVisible/);
  assert.match(shell, /keyboard: qmlKeyboard[\s\S]*?recording: qmlRecording/);
  assert.deepEqual(shellHints["SystemContent.statusInspection"], {
    scope: "controls",
    template: "SHIFT+I",
  });
});

test("System Status consumes its refresh shortcut before Controls actions", () => {
  const controls = qml("SystemContent.qml");
  const input = controls.slice(controls.indexOf("id: keyboardFocus"));
  const localStatus = input.indexOf("if (root.statusOpen)");
  const resourcesAction = input.indexOf("root.findDashboardAction(");
  const statusKeys = input.slice(
    localStatus,
    input.indexOf("if (root.mixerOpen)", localStatus),
  );

  assert.ok(localStatus >= 0 && localStatus < resourcesAction);
  assert.match(
    statusKeys,
    /shellMatchesHint\("StatusContent\.refresh", event\.key, event\.modifiers\)/,
  );
  assert.match(statusKeys, /statusContent\.triggerRefresh\(\)/);
  assert.match(statusKeys, /root\.backFromDetail\(\)/);
  assert.match(statusKeys, /return;/);
  assert.match(
    controls,
    /function refreshStatus\(\): void \{[\s\S]*?keyboard\.refresh\("inspect"\);[\s\S]*?brightness\.refresh\(\);/,
  );
  assert.match(controls, /onRefreshRequested: root\.refreshStatus\(\)/);
  assert.doesNotMatch(qml("StatusContent.qml"), /KeyHintStrip\s*\{/);
  assert.match(
    qml("StatusContent.qml"),
    /shortcut: content\.runtime\.shellHint\("StatusContent\.refresh"\)/,
  );
  assert.match(
    controls,
    /readonly property bool sliderNavigationEnabled:[^\n]*!statusOpen/,
  );
  assert.match(
    controls,
    /readonly property var helpBindings: settingsPanel\.open \? \[[\s\S]*?vhsPanel\.open \? \[[\s\S]*?statusOpen \? \[/,
  );
  assert.deepEqual(shellHints["StatusContent.refresh"], {
    scope: "status",
    template: "R",
  });
});

test("displays uses standard notifications and the status island owns only live state", () => {
  const controls = qml("SystemContent.qml");
  const shell = qml("shell.qml");
  const bar = qml("AmbientBar.qml");
  const island = qml("SystemIsland.qml");
  const notices = qml("EventNotifications.qml");
  assert.match(
    controls,
    /title: "Displays"[\s\S]*?onDetailsRequested: root\.openSetting\("displays"\)/,
  );
  assert.match(
    shell,
    /EventNotifications \{[\s\S]*?onDisplaySettingsRequested:/,
  );
  assert.match(notices, /"monitoraddedv2"/);
  assert.match(notices, /"Configure Displays"/);
  assert.match(notices, /"--action=open=" \+ action/);
  assert.doesNotMatch(
    bar,
    /displayContext|displayActionVisible|offerDisplaySettings/,
  );
  assert.doesNotMatch(
    island,
    /displayActionVisible|displayPress|displaySettingsRequested/,
  );
  assert.doesNotMatch(bar, /WlrLayershell\.namespace: "desktop-shell-context"/);
});

test("local OCR exposes selectable text and highlighted original-image coordinates", () => {
  const library = qml("RecordingLibrary.qml");
  const controls = qml("SystemContent.qml");
  const script = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/scripts/recordings.sh",
    ),
    "utf8",
  );
  assert.match(library, /function showText\(\): void/);
  assert.match(library, /function parseWords\(tsv: string\): var/);
  assert.match(
    library,
    /function selectWordAt\(x: real, y: real, extend: bool\): void/,
  );
  assert.match(library, /TextArea \{[\s\S]*?selectByMouse: true/);
  assert.match(library, /function copyHighlightedText\(\): void/);
  assert.match(
    library,
    /function moveWordSelection\(direction: int, extend: bool\): void/,
  );
  assert.match(library, /function selectAllWords\(\): void/);
  assert.match(library, /library\.keyboardRequested\(\);/);
  assert.doesNotMatch(library, /recognisedText\.forceActiveFocus\(\)/);
  assert.match(
    controls,
    /recordingsPanel\.invoke\("moveWordSelection", 1, shifted\)/,
  );
  assert.match(controls, /recordingsPanel\.invoke\("copyHighlightedText"\)/);
  assert.match(controls, /recordingsPanel\.invoke\("selectAllWords"\)/);
  assert.match(
    controls,
    /else if \(recordingsPanel\.open && recordingsPanel\.panel && recordingsPanel\.panel\.ocrVisible\) \{\s*recordingsPanel\.invoke\("closeText"\)/,
  );
  assert.deepEqual(shellHints["RecordingLibrary.extend"], {
    scope: "controls",
    template: "NAV_HORIZONTAL_SHIFT",
  });
  assert.match(library, /onActivated: library\.showText\(\)/);
  assert.match(controls, /shellMatchesHint\("RecordingLibrary\.ocr"/);
  assert.deepEqual(shellHints["RecordingLibrary.ocr"], {
    scope: "controls",
    template: "SHIFT+O",
  });
  assert.match(script, /tesseract "\$path" stdout -l eng tsv/);
  assert.match(script, /jq -Rs --arg text "\$text"/);
  assert.match(script, /trap 'rm -f -- "\$frame"' EXIT/);
  assert.doesNotMatch(script, /https?:\/\//);
});

test("Help effect keeps tile geometry, footer and outline on their existing owners", () => {
  const host = qml("ShellExpansionHost.qml");
  const help = qml("WidgetHelp.qml");
  assert.match(
    host,
    /id: contentViewport[\s\S]*?layer\.enabled: scopedHelp\.visible && host\.theme\.shellGlassEnabled/,
  );
  assert.match(
    host,
    /opacity: shellSurface\.contentReveal \* \(host\.theme\.shellGlassEnabled \? 1 - scopedHelp\.opacity \* 0\.56 : 1\)/,
  );
  assert.match(
    host,
    /layer\.effect: MultiEffect \{[\s\S]*?blur: scopedHelp\.opacity[\s\S]*?blurMax: 48/,
  );
  assert.match(help, /help\.contentArea\.mapToItem\(help, 0, 0\)\.x/);
  assert.match(help, /help\.contentArea\.mapToItem\(help, 0, 0\)\.y/);
  assert.match(help, /help\.theme\.shellGlassEnabled \? 0\.36 : 0\.70/);
  assert.match(host, /blurMax: 48/);
  assert.doesNotMatch(host, /blurMultiplier: 1\.5/);
  assert.match(host, /id: hubFooter\s+z: 250/);
  assert.match(
    help,
    /MouseArea \{\s+anchors\.fill: parent\s+enabled: help\.open\s+onClicked: help\.dismissed\(\)/,
  );
  assert.doesNotMatch(
    help,
    /ShaderEffectSource|MultiEffect|hideSource|blurSource|maskSource/,
  );
  assert.doesNotMatch(help, /PanelWindow/);
});
