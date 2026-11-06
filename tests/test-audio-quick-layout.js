const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const qml = (name) => fs.readFileSync(path.join(root, name), "utf8");

test("Controls and the expanded workspace instantiate the same mixer component", () => {
  const controls = qml("SystemContent.qml");
  const mixer = qml("AudioMixerContent.qml");
  assert.match(
    controls,
    /id: audioDeck[\s\S]*?compact: true[\s\S]*?onExpandRequested: root\.openMixer\(\)/,
  );
  assert.match(controls, /id: mixerView[\s\S]*?AudioMixerContent \{/);
  assert.match(mixer, /property bool compact: false/);
  assert.match(mixer, /visible: mixer\.compact/);
  assert.match(mixer, /visible: !mixer\.compact/);
  assert.equal(fs.existsSync(path.join(root, "AudioQuickSection.qml")), false);
});

test("one shared device primitive retains output/input volume, mute and live selection", () => {
  const device = qml("AudioDeviceControl.qml");
  const mixer = qml("AudioMixerContent.qml");
  for (const value of [
    /function toggleDeviceChooser\(\)/,
    /function moveDeviceSelection\(delta: int\)/,
    /function selectDevice\(index: int\)/,
    /system\.selectAudioDevice\(microphone, node\)/,
    /system\.toggleMicrophoneMute\(\)/,
    /system\.toggleMute\(\)/,
    /system\.setMicrophoneVolume\(value\)/,
    /system\.setVolume\(value\)/,
    /AudioPeakMeter \{/,
    /ShellSlider \{/,
    /Accessible\.name: deviceControl\.microphone \? "Microphone volume" : "Output volume"/,
    /onDevicesChanged: \{/,
  ])
    assert.match(device, value);
  assert.match(mixer, /id: outputDevice[\s\S]*?AudioDeviceControl/);
  assert.match(mixer, /id: inputDevice/);
  assert.match(mixer, /onChooserOpenChanged: \{/);
  assert.match(
    mixer,
    /deviceChooserOpen: outputDevice\.chooserOpen \|\| inputDevice\.chooserOpen/,
  );
});

test("the same virtualised stream control handles every playback and capture client", () => {
  const mixer = qml("AudioMixerContent.qml");
  const channel = qml("AudioStreamControl.qml");
  assert.match(
    mixer,
    /readonly property var streams: system\.audioApplicationStreams\.concat\(system\.audioCaptureStreams\)/,
  );
  assert.match(mixer, /model: mixer\.streams\.length/);
  assert.match(mixer, /orientation: ListView\.Vertical/);
  assert.match(mixer, /cacheBuffer: 90/);
  assert.match(
    mixer,
    /monitoring: mixer\.active && list\.visible && streamRow\.inViewport/,
  );
  assert.match(mixer, /AudioStreamControl \{/);
  assert.match(
    mixer,
    /onSelectedRequested: mixer\.selectStreamIndex\(streamRow\.index\)/,
  );
  assert.match(channel, /channel\.system\.toggleStreamMute\(channel\.stream\)/);
  assert.match(
    channel,
    /channel\.system\.setStreamVolume\(channel\.stream, value\)/,
  );
  assert.match(channel, /AudioPeakMeter \{/);
  assert.doesNotMatch(mixer, /audioApplicationStreams\.slice\(0, 2\)/);
});

test("stream selection stays with the node across reordering and services share one action owner", () => {
  const mixer = qml("AudioMixerContent.qml");
  const controls = qml("SystemContent.qml");
  assert.match(mixer, /property var selectedNode: null/);
  assert.match(
    mixer,
    /selectedNode \? targets\.findIndex\(target => target\.node === selectedNode\)/,
  );
  assert.match(mixer, /onTargetsChanged: \{/);
  assert.match(mixer, /function moveAudioSelection\(delta: int\)/);
  assert.match(mixer, /function adjustSelected\(delta: real\)/);
  assert.match(mixer, /function toggleSelectedMute\(\)/);
  assert.match(mixer, /function toggleSelectedDeviceChooser\(\)/);
  assert.match(controls, /audioDeck\.moveAudioSelection\(direction\)/);
  assert.match(controls, /audioDeck\.adjustSelected\(delta\)/);
  assert.match(controls, /audioDeck\.toggleSelectedMute\(\)/);
  assert.match(controls, /audioDeck\.toggleSelectedDeviceChooser\(\)/);
  assert.match(
    controls,
    /mixerView\.panel\.handleKey\(event\.key, event\.modifiers\)/,
  );
});

test("compact and expanded audio handling retain the complete keyboard contract", () => {
  const mixer = qml("AudioMixerContent.qml");
  const controls = qml("SystemContent.qml");
  assert.match(mixer, /if \(picker\) \{/);
  assert.match(mixer, /picker\.moveDeviceSelection\(1\)/);
  assert.match(mixer, /picker\.selectDevice\(picker\.chooserIndex\)/);
  assert.match(mixer, /key === Qt\.Key_M/);
  assert.match(mixer, /key === Qt\.Key_P/);
  assert.match(mixer, /key === Qt\.Key_Tab \|\| key === Qt\.Key_Backtab/);
  assert.match(controls, /if \(audioDeck\.deviceChooserOpen\) \{/);
  assert.match(
    controls,
    /audioDeck\.handleKey\(event\.key, event\.modifiers\)/,
  );
  assert.match(controls, /root\.muteSelectedAudio\(\)/);
});

test("mixer selection follows visual left-to-right order before descending through streams", () => {
  const mixer = qml("AudioMixerContent.qml");
  const start = mixer.indexOf("readonly property var targets: ");
  const end = mixer.indexOf("readonly property int microphoneIndex", start);
  assert.ok(start > 0 && end > start);
  const expression = mixer
    .slice(start + "readonly property var targets: ".length, end)
    .trim();
  const targets = new Function("system", "return (" + expression + ");");
  const result = targets({
    microphoneAvailable: true,
    audioApplicationStreams: [{ id: "music" }, { id: "browser" }],
    audioCaptureStreams: [{ id: "recorder" }],
  });
  assert.deepEqual(
    result.map((item) => (item.kind === "stream" ? item.node.id : item.kind)),
    ["output", "input", "music", "browser", "recorder"],
  );
  assert.ok(mixer.includes("key === Qt.Key_Down || key === Qt.Key_J"));
  assert.ok(mixer.includes("function moveAudioSelection(delta: int)"));
});

test("full mixer height matches visible channels before virtual scrolling", () => {
  const mixer = qml("AudioMixerContent.qml");
  assert.ok(mixer.includes("Math.min(330, mixer.streams.length * 102 + 36)"));
  assert.ok(mixer.includes("cacheBuffer: 90"));
  assert.ok(
    mixer.includes(
      "monitoring: mixer.active && list.visible && streamRow.inViewport",
    ),
  );
});
