const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = (name) => fs.readFileSync(path.join(root, "qml", name), "utf8");

test("blur uses the native compositor with persisted Nix precedence and bounded updates", () => {
  const settings = qml("AppearancePreferences.qml");
  const controls = qml("SystemContent.qml");
  const runtime = qml("RuntimeConfig.qml");
  const nix = fs.readFileSync(path.join(root, "default.nix"), "utf8");

  assert.match(
    nix,
    /blurSize = lib\.mkOption \{\s*type = lib\.types\.ints\.between 5 25;/,
  );
  assert.match(nix, /default = 15;/);
  assert.match(runtime, /property int blurSize: 15/);
  assert.match(
    settings,
    /readonly property int blurSize: .*effective\("blurSize"\)/,
  );
  assert.match(settings, /function setBlurSize\(value: real\): void/);
  assert.match(settings, /function applyBlurSize\(\): void/);
  assert.match(settings, /"hl\.config\(\{ decoration = \{ blur = \{ size = "/);
  assert.match(
    settings,
    /property Timer blurSizeApply: Timer \{\s*interval: 75/,
  );
  assert.match(controls, /title: "Blur softness"/);
  assert.match(
    controls,
    /onValueRequested: next => root\.appearance\.setBlurSize\(next\)/,
  );
  assert.match(controls, /readonly property var sliderTargets:.*"blur"/);
});

test("settings inspection and one-step undo share the existing appearance owner", () => {
  const settings = qml("AppearancePreferences.qml");
  const controls = qml("SystemContent.qml");

  assert.match(settings, /function hasOverride\(key: string\): bool/);
  assert.match(settings, /function restoreSetting\(key: string\): void/);
  assert.match(settings, /function beginAdjustment\(key: string\): void/);
  assert.match(settings, /function undoLastChange\(\): void/);
  assert.match(settings, /relatedOverridden/);
  assert.match(controls, /"User override" : "Nix default"/);
  assert.match(controls, /appearance\.restoreSetting\(selectedAppearanceKey\)/);
  assert.match(controls, /appearance\.undoLastChange\(\)/);
  assert.doesNotMatch(settings, /while\s*\(|setInterval\s*\(/);
});

test("status and displays are direct Controls actions with one shared entry point", () => {
  const controls = qml("SystemContent.qml");
  const shell = qml("shell.qml");
  const runtime = qml("RuntimeConfig.qml");
  const bindings = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");

  assert.match(
    controls,
    /title: "Status"[\s\S]*?onActivated: root\.statusInspectionRequested\(\)/,
  );
  assert.match(
    controls,
    /title: "Displays"[\s\S]*?onActivated: root\.displaySettingsRequested\(\)/,
  );
  assert.match(
    shell,
    /onStatusInspectionRequested:[\s\S]*?root\.toggleStatusInspection\(qmlScreens\.focusedScreen\)/,
  );
  assert.match(
    shell,
    /onDisplaySettingsRequested:[\s\S]*?Quickshell\.execDetached\(\[qmlRuntime\.displaySettings\]\)/,
  );
  assert.match(runtime, /readonly property string displaySettings:/);
  assert.match(
    bindings,
    /"SystemContent\.statusInspection" = \{\s*scope = "controls";\s*template = "SHIFT\+I";/,
  );
});

test("contextual monitor action shares system island rather than competing with notifications", () => {
  const bar = qml("AmbientBar.qml");
  const island = qml("SystemIsland.qml");

  assert.match(bar, /event\.name !== "monitoradded"/);
  assert.match(bar, /interval: 12000/);
  assert.match(bar, /displayActionVisible: bar\.displayContextVisible/);
  assert.match(island, /Accessible\.name: "Configure newly connected display"/);
  assert.match(island, /onActivated: island\.displaySettingsRequested\(\)/);
  assert.doesNotMatch(bar, /WlrLayershell\.namespace: "linux-desktop-context"/);
});

test("local OCR remains an action on saved images and video frames", () => {
  const library = qml("RecordingLibrary.qml");
  const controls = qml("SystemContent.qml");
  const script = fs.readFileSync(
    path.join(__dirname, "../scripts/linux-desktop/recordings.sh"),
    "utf8",
  );

  assert.match(library, /function copyText\(\): void/);
  assert.match(
    library,
    /ocrProcess\.exec\(\[runtime\.recordingLibrary, "ocr", selectedEntry\.name\]\)/,
  );
  assert.match(controls, /shellMatchesHint\("RecordingLibrary\.ocr"/);
  assert.match(script, /preview \| open \| edit \| copy \| trash \| ocr\)/);
  assert.match(script, /tesseract "\$path" stdout -l eng/);
  assert.match(script, /wl-copy --type text\/plain/);
  assert.match(script, /trap 'rm -f -- "\$frame"' EXIT/);
  assert.doesNotMatch(script, /https?:\/\//);
});
