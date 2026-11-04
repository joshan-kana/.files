const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const source = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/ReactiveAudio.js",
  ),
  "utf8",
);
const ctx = vm.createContext({ Math, Number, Infinity });
vm.runInContext(source, ctx);
function state() {
  return {
    sustain: 0,
    beatPulse: 0,
    treble: 0,
    kick: 0,
    body: 0,
    presence: 0,
    motionAmount: 0,
    spectrumLevels: [0, 0, 0, 0, 0, 0, 0, 0, 0],
    bassBaseline: 0,
    peakBaseline: 0,
    rmsBaseline: 0,
    midBaseline: 0,
    fluxBaseline: 0,
    sinceKick: 1,
    previousBands: [],
    baselineReady: false,
  };
}
const bandHz = (i) => 20 * Math.exp(Math.log(20000 / 20) * (i / 95));
function audio(attack = 0, subAmplitude = 0.9) {
  const bands = Array.from({ length: 96 }, (_, i) => {
    const hz = bandHz(i);
    const sustained =
      hz >= 30 && hz <= 59
        ? 0.9 * subAmplitude
        : hz >= 60 && hz <= 250
          ? 0.03
          : hz > 250 && hz < 2100
            ? 0.045
            : 0.015;
    const transient =
      hz >= 70 && hz < 180
        ? attack * 0.55
        : hz >= 250 && hz < 2100
          ? attack * 0.38
          : 0;
    return Math.min(1, sustained + transient);
  });
  return {
    rms: 0.16 + attack * 0.05,
    peak: 0.42 + attack * 0.22,
    sub: subAmplitude,
    bass: 0.38 + attack * 0.16,
    mid: 0.18 + attack * 0.07,
    high: 0.1,
    bands,
    lowHz: 20,
    highHz: 20000,
  };
}
function settle(s, frames = 150) {
  for (let i = 0; i < frames; i++) ctx.advanceAudio(s, audio(), 0.01);
}
test("continuous high-energy 808 establishes colour without false kick retriggers", () => {
  const s = state();
  settle(s);
  assert.ok(s.sustain > 0.1, "steady 808 should preserve colour presence");
  assert.ok(s.sustain < 0.7, "bass alone should not saturate the colour field");
  assert.ok(s.kick < 0.001, "unvarying 808 should not trigger kicks");
  const start = [...s.spectrumLevels],
    old = s.sustain;
  for (let i = 0; i < 150; i++) ctx.advanceAudio(s, audio(), 0.01);
  assert.ok(s.kick < 0.001, "sustained 808 must not flash");
  assert.ok(
    Math.abs(s.sustain - old) < 0.01,
    "sustained bass should not pump intensity",
  );
  assert.ok(
    start.every((level, i) => Math.abs(level - s.spectrumLevels[i]) < 0.00001),
    "identical steady FFT frames must not produce perpetual visual motion",
  );
});
test("kicks remain detectable on top of loud 808s, including at half-second intervals", () => {
  const s = state();
  settle(s);
  const kickValues = [];
  for (let i = 0; i < 300; i++) {
    const beat = i % 50;
    const attack = beat < 5 ? Math.exp(-beat * 0.55) : 0;
    ctx.advanceAudio(s, audio(attack), 0.01);
    if (beat === 1) kickValues.push(s.kick);
  }
  assert.ok(kickValues.length >= 5);
  assert.ok(
    kickValues.filter((v) => v > 0.11).length >= 5,
    "each kick must trigger even while the 808 stays high",
  );
});
test("808 amplitude modulation without a kick's upper-band onset stays calm", () => {
  const s = state();
  settle(s);
  let largest = 0;
  for (let i = 0; i < 160; i++) {
    const frame = audio();
    const sweep = 0.7 + 0.3 * Math.sin(i * 0.05) ** 2;
    frame.sub = sweep;
    for (let b = 0; b < frame.bands.length; b++)
      if (bandHz(b) < 60) frame.bands[b] *= sweep;
    ctx.advanceAudio(s, frame, 0.01);
    largest = Math.max(largest, s.kick);
  }
  assert.ok(
    largest < 0.08,
    "sub-bass changes should not masquerade as kick transients",
  );
});
test("treble and melody change motion without increasing kick or the bass foundation", () => {
  const s = state();
  settle(s);
  const first = s.kick;
  for (let i = 0; i < 80; i++) {
    const frame = audio();
    frame.high = 0.7;
    frame.mid = 0.65;
    ctx.advanceAudio(s, frame, 0.01);
  }
  assert.ok(s.body > 0.25);
  assert.ok(s.treble > 0.35);
  assert.ok(s.motionAmount > 0.3);
  assert.ok(s.kick < 0.08);
  assert.ok(Math.abs(s.kick - first) < 0.08);
});

test("musical onsets change only relevant zones, then settle without drifting", () => {
  const s = state();
  settle(s);
  const baseline = [...s.spectrumLevels];
  for (let i = 0; i < 3; i++) ctx.advanceAudio(s, audio(0.95), 0.01);
  const attack = [...s.spectrumLevels];
  assert.ok(attack[1] > baseline[1] + 0.07, "kick must animate low-mid band");
  assert.ok(
    attack[3] > baseline[3] + 0.04,
    "transient should reach punch range",
  );
  assert.ok(
    attack[1] - baseline[1] > attack[0] - baseline[0],
    "sustained 808 must not dominate the kick",
  );
  settle(s);
  const stable = [...s.spectrumLevels];
  settle(s);
  assert.ok(
    stable.every((v, i) => Math.abs(v - s.spectrumLevels[i]) < 0.00001),
    "no fake motion after the audio has stabilised",
  );
});

test("notes in higher bands animate blue and cyan without lifting the sub-bass", () => {
  const s = state();
  settle(s);
  const before = [...s.spectrumLevels];
  const frame = audio();
  frame.high = 0.68;
  frame.mid = 0.53;
  for (let i = 0; i < frame.bands.length; i++) {
    const hz = bandHz(i);
    if (hz > 800 && hz < 5000) frame.bands[i] = 0.82;
  }
  for (let i = 0; i < 5; i++) ctx.advanceAudio(s, frame, 0.01);
  assert.ok(s.spectrumLevels[5] > before[5] + 0.2);
  assert.ok(s.spectrumLevels[6] > before[6] + 0.2);
  assert.ok(Math.abs(s.spectrumLevels[0] - before[0]) < 0.01);
});

test("pausing playback releases FFT zones and visible tint promptly", () => {
  const s = state();
  settle(s);
  const silent = audio();
  for (const key of ["rms", "peak", "sub", "bass", "mid", "high"])
    silent[key] = 0;
  silent.bands.fill(0);
  for (let i = 0; i < 55; i++) ctx.advanceAudio(s, silent, 0.01);
  assert.ok(
    Math.max(...s.spectrumLevels) < 0.01,
    "spectral glow fades in under a second",
  );
  assert.ok(
    s.sustain < 0.01,
    "base tint fades rather than lingering for five seconds",
  );
  assert.ok(s.kick < 0.01);
});
