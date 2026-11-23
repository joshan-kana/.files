const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const source = name => fs.readFileSync(path.join(root, "qml", name), "utf8");
const shellModule = fs.readFileSync(path.join(root, "default.nix"), "utf8");
const keymap = JSON.parse(execFileSync("nix", ["eval", "--json", "--impure", "--expr", "import ./modules/desktop/hyprland/shell/keybindings.nix"], {
  cwd: path.join(__dirname, ".."), encoding: "utf8"
}));

test("EasyEffects owns DSP while the shell uses its documented bypass CLI only", () => {
  const state = source("EasyEffectsState.qml");
  assert.match(state, /required property RuntimeConfig runtime/);
  assert.match(state, /readonly property bool supported: runtime\.easyeffects\.length > 0/);
  assert.match(state, /queryProcess\.exec\(\[runtime\.easyeffects, "--bypass", "3"\]\)/);
  assert.match(state, /actionProcess\.exec\(\[runtime\.easyeffects, "--bypass", desiredBypass \? "1" : "2"\]\)/);
  assert.match(state, /result === "1" \|\| result === "2"/);
  assert.match(state, /effects\.awaitingConfirmation && effects\.bypassed !== effects\.desiredBypass/);
  assert.match(state, /Quickshell\.execDetached\(\[runtime\.easyeffects\]\)/);
  assert.doesNotMatch(state, /setInterval|repeat: true|PipeWire\.|wpctl|filter-chain|loadPreset|createSink/);
  assert.match(shellModule, /easyeffects = lib\.getExe pkgs\.easyeffects;/);
  assert.match(source("RuntimeConfig.qml"), /readonly property string easyeffects: root\.configData\.tools\.easyeffects/);
});

test("full Audio Mixer exposes status, bypass, refresh and standalone editor without a compact DSP duplicate", () => {
  const mixer = source("AudioMixerContent.qml");
  const controls = source("SystemContent.qml");
  assert.match(mixer, /EasyEffectsState \{[\s\S]*?runtime: mixer\.runtime/);
  assert.match(mixer, /if \(!compact\)\s*effectsState\.refresh\(\)/);
  assert.match(mixer, /id: postProcessing[\s\S]*?visible: !mixer\.compact && effectsState\.supported/);
  assert.match(mixer, /text: effectsState\.statusLabel/);
  assert.match(mixer, /onActivated: effectsState\.toggleBypass\(\)/);
  assert.match(mixer, /onActivated: effectsState\.openEditor\(\)/);
  assert.match(mixer, /onActivated: effectsState\.refresh\(\)/);
  assert.match(mixer, /handleKey\(key: int, modifiers: int, autoRepeat: bool\)/);
  assert.match(mixer, /if \(!autoRepeat\)\s*effectsState\.toggleBypass\(\)/);
  assert.match(controls, /mixerView\.panel\.handleKey\(event\.key, event\.modifiers, event\.isAutoRepeat\)/);
  assert.doesNotMatch(mixer, /equalizerBand|compressorRatio|convolverImpulse|setDefaultSink/);
});

test("effect actions use the canonical mixer-local keyboard registry", () => {
  for (const [name, assigned] of [
    ["AudioMixerContent.effectsToggle", "B"],
    ["AudioMixerContent.effectsOpen", "E"],
    ["AudioMixerContent.effectsRefresh", "R"]
  ]) {
    assert.deepEqual(keymap.hints[name], { scope: "mixer", template: assigned });
    assert.ok(source("AudioMixerContent.qml").includes('shellHint("' + name + '")'));
    assert.ok(source("AudioMixerContent.qml").includes('shellMatchesHint("' + name + '"'));
  }
});
