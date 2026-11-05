const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/MusicReactiveState.qml",
  ),
  "utf8",
);

function bodyOf(name) {
  const start = source.indexOf(`function ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const open = source.indexOf("{", start);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === "{") depth++;
    else if (source[i] === "}" && --depth === 0)
      return source.slice(open + 1, i);
  }
  throw new Error(`unclosed ${name}`);
}

const update = new Function(
  "state",
  "spectrum",
  "Date",
  `with (state) { ${bodyOf("updateAudio")} }`,
);

function newReactiveState() {
  const state = {
    enabled: true,
    sustain: 0,
    beatPulse: 0,
    treble: 0,
    bassBaseline: 0,
    peakBaseline: 0,
    bassVariation: 0,
    baselineReady: false,
    lastUpdateMs: 0,
    clamp: (value) => Math.max(0, Math.min(1, value)),
  };
  state.reset = () => {
    for (const field of [
      "sustain",
      "beatPulse",
      "treble",
      "bassBaseline",
      "peakBaseline",
      "bassVariation",
      "lastUpdateMs",
    ])
      state[field] = 0;
    state.baselineReady = false;
  };
  return state;
}
function audio(sub = 0.7, bass = 0.4, peak = 0.4, high = 0.14) {
  return { connected: true, rms: 0.15, peak, sub, bass, mid: 0.21, high };
}
function step(state, spectrum, now) {
  update(state, spectrum, { now: () => now });
}

test("the original colour gradient uses one continuous bass envelope and a separate beat pulse", () => {
  const state = newReactiveState();
  for (let i = 1; i <= 80; i++) step(state, audio(), i * 20);
  assert.ok(state.sustain > 0.15);
  assert.ok(state.beatPulse < 0.01, "held bass does not repeatedly pulse");
  const steady = state.sustain;
  for (let i = 81; i <= 120; i++) step(state, audio(), i * 20);
  assert.ok(Math.abs(state.sustain - steady) < 0.0001);
  step(state, audio(0.95, 0.92, 0.89), 2420);
  assert.ok(
    state.beatPulse > 0.15,
    "a louder low-frequency attack produces a distinct accent",
  );
  assert.ok(state.sustain > 0);
  for (let i = 122; i <= 158; i++) step(state, audio(), i * 20);
  assert.ok(
    state.beatPulse < 0.05,
    "a pulse settles without sustained strobing",
  );
});

test("original reactive state returns to zero on silence or disconnection", () => {
  const state = newReactiveState();
  step(state, audio(), 20);
  step(state, audio(0.9, 0.9, 0.82, 0.8), 40);
  assert.ok(state.sustain > 0);
  step(state, { ...audio(), rms: 0, peak: 0 }, 60);
  assert.deepEqual([state.sustain, state.beatPulse, state.treble], [0, 0, 0]);
  step(state, audio(), 80);
  step(state, { ...audio(), connected: false }, 100);
  assert.deepEqual([state.sustain, state.beatPulse, state.treble], [0, 0, 0]);
});

test("rollback does not retain the later nine-band impulse processing pipeline", () => {
  assert.doesNotMatch(
    source,
    /ReactiveAudio\.js|spectrumLevels|impulseLevels|FrameAnimation|state\.kick/,
  );
  assert.match(source, /onSequenceChanged/);
  assert.match(
    source,
    /const range = Math\.max\(0\.07, bassVariation \* 2\.7\)/,
  );
});
