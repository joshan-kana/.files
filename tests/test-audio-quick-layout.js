const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("output and input devices retain mute, volume, picker and mixer controls inside one tile", () => {
  const quick = qml("AudioQuickSection.qml");
  assert.match(
    quick,
    /id: inlineControl[\s\S]*?surfaceLayer: ShellSurface\.Control/,
  );
  assert.match(quick, /height: inlineContents\.implicitHeight/);
  assert.match(quick, /onActivated: \{[\s\S]*?quick\.system\.toggleMute\(\)/);
  assert.match(
    quick,
    /onValueRequested: value => \{[\s\S]*?quick\.system\.setVolume\(value\)/,
  );
  assert.match(quick, /onActivated: quick\.mixerRequested\(\)/);
  assert.match(quick, /parent: quick\.inline \? inlineContents : quick/);
  assert.match(
    quick,
    /shortcut: quick\.selectedAudioIndex === quick\.baseIndex \? "P" : ""/,
  );
  assert.match(quick, /hovered: tileHover\.hovered/);
  assert.match(quick, /onDevicesChanged: \{/);
  assert.match(quick, /Accessible.role: Accessible.Grouping/);
  assert.match(quick, /Accessible.name: "Open application mixer"/);
  assert.match(
    quick,
    /Accessible.name: quick.microphone \? "Microphone level" : "Output level"/,
  );
});

test("both compact tiles retain independent channel mute, volume, peaks and stream selection", () => {
  const quick = qml("AudioQuickSection.qml");
  const channel = qml("AudioStreamControl.qml");
  assert.match(
    quick,
    /readonly property var streams: microphone \? system\.audioCaptureStreams : system\.audioApplicationStreams/,
  );
  assert.match(quick, /model: quick\.activeStreamCount/);
  assert.match(quick, /delegate: AudioStreamControl \{/);
  assert.match(quick, /quick\.baseIndex \+ index \+ 1/);
  assert.match(
    quick,
    /monitoring: quick\.meterEnabled && quick\.inline && streamEntry\.inViewport/,
  );
  assert.match(
    quick,
    /height: visible \? Math\.min\(2, quick\.activeStreamCount\)/,
  );
  assert.match(channel, /IconShortcutAction \{/);
  assert.match(channel, /shortcut: channel\.selected \? "M" : ""/);
  assert.match(channel, /channel\.system\.toggleStreamMute\(channel\.stream\)/);
  assert.match(channel, /ShellSlider \{/);
  assert.match(
    channel,
    /channel\.system\.setStreamVolume\(channel\.stream, value\)/,
  );
  assert.match(channel, /AudioPeakMeter \{/);
  assert.match(channel, /Accessible.name: channel.displayName \+ " volume"/);
  assert.match(
    channel,
    /monitoring: channel\.monitoring && channel\.available/,
  );
  assert.doesNotMatch(
    quick,
    /audioApplicationStreams\.slice\(0, 2\)|audioCaptureStreams\.slice\(0, 2\)/,
  );
});

test("keyboard selection covers every live channel and preserves identity across reordering", () => {
  const controls = qml("SystemContent.qml");
  assert.match(controls, /system\.audioApplicationStreams\.map\(node/);
  assert.match(controls, /system\.audioCaptureStreams\.map\(node/);
  assert.match(
    controls,
    /readonly property int microphoneAudioIndex: 1 \+ system\.audioApplicationStreams\.length/,
  );
  assert.match(controls, /selectedAudioNode: null/);
  assert.match(
    controls,
    /quickAudioTargets\.findIndex\(target => target\.node === selectedAudioNode\)/,
  );
  assert.match(controls, /function selectAudioIndex\(index: int\)/);
  assert.match(controls, /root\.moveAudioSelection\(1\)/);
  assert.match(controls, /root\.muteSelectedAudio\(\)/);
  assert.match(controls, /root\.adjustSelectedAudio\(0\.05\)/);
});

test("expanded mixer reuses the same channel component and virtualises peak monitoring", () => {
  const mixer = qml("AudioMixerContent.qml");
  const controls = qml("SystemContent.qml");
  assert.match(mixer, /orientation: ListView\.Vertical/);
  assert.match(mixer, /property var selectedNode: null/);
  assert.match(mixer, /const current = streams\.indexOf\(selectedNode\)/);
  assert.match(mixer, /onStreamsChanged: \{/);
  assert.match(mixer, /delegate: Item \{/);
  assert.match(mixer, /AudioStreamControl \{/);
  assert.match(
    mixer,
    /monitoring: mixer\.active && list\.visible && streamRow\.inViewport/,
  );
  assert.match(
    mixer,
    /onSelectedRequested: mixer\.selectIndex\(streamRow\.index\)/,
  );
  assert.match(mixer, /key === Qt\.Key_Tab \|\| key === Qt\.Key_Backtab/);
  assert.match(
    controls,
    /mixerView\.panel\.handleKey\(event\.key, event\.modifiers\)/,
  );
});
