const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = (name) => fs.readFileSync(path.join(root, "qml", name), "utf8");

test("blur uses one live compositor parameter within the frosted-glass tile", () => {
  const settings = qml("AppearancePreferences.qml");
  const controls = qml("SystemContent.qml");
  const tile = qml("OpacitySetting.qml");
  const runtime = qml("RuntimeConfig.qml");
  const nix = fs.readFileSync(path.join(root, "default.nix"), "utf8");

  assert.match(
    nix,
    /blurSize = lib\.mkOption \{\s*type = lib\.types\.ints\.between 5 25;/,
  );
  assert.match(runtime, /property int blurSize: 15/);
  assert.match(
    settings,
    /readonly property int blurSize: .*effective\("blurSize"\)/,
  );
  assert.match(settings, /function setBlurSize\(value: real\): void/);
  assert.match(settings, /"hl\.config\(\{ decoration = \{ blur = \{ size = "/);
  assert.match(
    settings,
    /property Timer blurSizeApply: Timer \{\s*interval: 75/,
  );
  assert.doesNotMatch(controls, /title: "Blur softness"/);
  assert.match(
    controls,
    /label: "Frosted glass"[\s\S]*?blurAdjustable: true[\s\S]*?onBlurRequested: value => root\.appearance\.setBlurSize\(value\)/,
  );
  assert.match(tile, /property bool blurAdjustable: false/);
  assert.match(tile, /Accessible\.name: "Adjust frosted-glass blur softness"/);
  assert.match(
    tile,
    /value: setting\.blurEditing \? setting\.blurValue : setting\.opacityValue/,
  );
  assert.match(
    controls,
    /readonly property var sliderTargets:.*"glass", "blur"/,
  );
});

test("visual parameter controls do not add a separate appearance action row", () => {
  const controls = qml("SystemContent.qml");
  const settings = qml("AppearancePreferences.qml");
  const shortcuts = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");
  assert.doesNotMatch(
    controls,
    /Undo appearance|Choose a visual setting|selectedAppearanceKey|resetSelectedAppearance/,
  );
  assert.doesNotMatch(
    settings,
    /lastAppearanceChange|beginAdjustment|undoLastChange/,
  );
  assert.doesNotMatch(
    shortcuts,
    /SystemContent\.undoAppearance|SystemContent\.resetSetting/,
  );
  assert.doesNotMatch(controls, /opacitySettingsButton|openTransparency/);
});

test("status is a Controls detail with shared data and nested Escape", () => {
  const controls = qml("SystemContent.qml");
  const host = qml("ShellExpansionHost.qml");
  const shell = qml("shell.qml");
  const bindings = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");
  assert.match(
    controls,
    /title: "Status"[\s\S]*?onActivated: root\.openStatus\(\)/,
  );
  assert.match(controls, /function openStatus\(\): void/);
  assert.match(controls, /StatusContent \{[\s\S]*?keyboard: root\.keyboard/);
  assert.match(controls, /onCloseRequested: root\.backFromDetail\(\)/);
  assert.match(host, /systemContent\.statusOpen/);
  assert.match(shell, /keyboard: qmlKeyboard[\s\S]*?recording: qmlRecording/);
  assert.match(
    bindings,
    /"SystemContent\.statusInspection" = \{\s*scope = "controls";\s*template = "SHIFT\+I";/,
  );
});

test("System Status consumes its refresh shortcut before Controls actions", () => {
  const controls = qml("SystemContent.qml");
  const bindings = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");
  const input = controls.slice(controls.indexOf("id: keyboardFocus"));
  const localStatus = input.indexOf("if (root.statusOpen)");
  const resourcesAction = input.lastIndexOf("root.openResources()");
  const statusKeys = input.slice(
    localStatus,
    input.indexOf("if (root.mixerOpen)", localStatus),
  );

  assert.ok(localStatus >= 0 && localStatus < resourcesAction);
  assert.match(
    statusKeys,
    /shellMatchesHint\("StatusContent\.refresh", event\.key, event\.modifiers\)/,
  );
  assert.match(statusKeys, /root\.refreshStatus\(\)/);
  assert.match(statusKeys, /root\.backFromDetail\(\)/);
  assert.match(statusKeys, /return;/);
  assert.match(
    controls,
    /function refreshStatus\(\): void \{[\s\S]*?keyboard\.refresh\("inspect"\);[\s\S]*?brightness\.refresh\(\);/,
  );
  assert.match(controls, /onRefreshRequested: root\.refreshStatus\(\)/);
  assert.match(
    controls,
    /closeLabel: root\.returnToControls \? "Back" : "Close"/,
  );
  assert.match(qml("StatusContent.qml"), /label: content\.closeLabel/);
  assert.match(
    controls,
    /readonly property bool sliderNavigationEnabled:[^\n]*!statusOpen/,
  );
  assert.match(
    controls,
    /readonly property var helpBindings: statusOpen \? \[/,
  );
  assert.match(
    bindings,
    /"StatusContent\.refresh" = \{\s*scope = "status";\s*template = "R";/,
  );
});

test("displays opens the native editor and contextual island avoids another popup", () => {
  const controls = qml("SystemContent.qml");
  const shell = qml("shell.qml");
  const bar = qml("AmbientBar.qml");
  const island = qml("SystemIsland.qml");
  assert.match(
    controls,
    /title: "Displays"[\s\S]*?onActivated: root\.displaySettingsRequested\(\)/,
  );
  assert.match(
    shell,
    /onDisplaySettingsRequested:[\s\S]*?Quickshell\.execDetached\(\[qmlRuntime\.displaySettings\]\)/,
  );
  assert.match(bar, /event\.name === "monitoradded"/);
  assert.match(bar, /property Timer displayContextTimeout: Timer/);
  assert.match(bar, /interval: 12000/);
  assert.match(bar, /bars\.displayContextTimeout\.restart\(\)/);
  assert.match(bar, /event\.name === "monitorremovedv2"/);
  assert.match(bar, /bars\.displayContextTimeout\.stop\(\)/);
  assert.match(
    bar,
    /displayActionVisible: bars\.displayContextScreen === bar\.modelData\.name/,
  );
  assert.match(bar, /property string displayContextScreen: ""/);
  assert.match(
    bar,
    /function offerDisplaySettings\(outputName: string\): void/,
  );
  assert.match(island, /Accessible\.name: "Configure newly connected display"/);
  assert.match(island, /onActivated: island\.displaySettingsRequested\(\)/);
  assert.doesNotMatch(bar, /WlrLayershell\.namespace: "linux-desktop-context"/);
});

test("local OCR exposes selectable text and highlighted original-image coordinates", () => {
  const library = qml("RecordingLibrary.qml");
  const controls = qml("SystemContent.qml");
  const script = fs.readFileSync(
    path.join(__dirname, "../scripts/linux-desktop/recordings.sh"),
    "utf8",
  );
  const shortcuts = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");
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
  assert.match(
    shortcuts,
    /"RecordingLibrary\.extend" = \{\s*scope = "controls";\s*template = "SHIFT\+H\/L";/,
  );
  assert.match(library, /onActivated: library\.showText\(\)/);
  assert.match(controls, /shellMatchesHint\("RecordingLibrary\.ocr"/);
  assert.match(
    shortcuts,
    /"RecordingLibrary\.ocr" = \{\s*scope = "controls";\s*template = "SHIFT\+O";/,
  );
  assert.match(script, /tesseract "\$path" stdout -l eng tsv/);
  assert.match(script, /jq -Rs --arg text "\$text"/);
  assert.match(script, /trap 'rm -f -- "\$frame"' EXIT/);
  assert.doesNotMatch(script, /https?:\/\//);
});

test("Help blur covers the whole rounded scrim with no competing Wayland window", () => {
  const help = qml("WidgetHelp.qml");
  assert.match(
    help,
    /sampleOrigin: help\.blurSource \? help\.blurSource\.mapFromItem\(backdrop, 0, 0\)/,
  );
  assert.match(help, /maskSource: blurMask/);
  assert.match(help, /sourceItem: help\.blurSource/);
  assert.match(help, /id: blurTexture\s+anchors\.fill: parent/);
  assert.match(help, /id: blurMask[\s\S]*?layer\.enabled: true/);
  assert.match(
    help,
    /fillColor: Qt\.rgba\(help\.theme\.background\.r, help\.theme\.background\.g, help\.theme\.background\.b, 1\)/,
  );
  assert.match(help, /visible: help\.open && help\.theme\.shellGlassEnabled/);
  assert.doesNotMatch(help, /PanelWindow/);
});
