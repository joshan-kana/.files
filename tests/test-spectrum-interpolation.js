const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/SpectrumState.qml",
  ),
  "utf8",
);

// Exercise the real QML JavaScript function body rather than independently
// rewriting the new interpolation algorithm in the test.
function qmlFunction(name) {
  const signature = new RegExp(`function ${name}\\([^)]*\\): void \\{`);
  const match = signature.exec(source);
  assert.ok(match, `${name} must exist`);
  const start = match.index + match[0].length;
  let depth = 1;
  let end = start;
  while (depth && end < source.length) {
    if (source[end] === "{") depth++;
    if (source[end] === "}") depth--;
    end++;
  }
  assert.equal(depth, 0);
  return new Function(
    "state",
    "frameTime",
    `with (state) { ${source.slice(start, end - 1)} }`,
  );
}

function referenceAdvance(state, delta) {
  const values = [];
  let maxDifference = 0;
  const bassEnd =
    (state.targetBands.length * Math.log(250 / Math.max(1, state.lowHz))) /
    Math.log(Math.max(2, state.highHz / Math.max(1, state.lowHz)));
  for (let i = 0; i < state.targetBands.length; i++) {
    const lowBand = i <= bassEnd;
    const rate = state.decaying
      ? 10
      : lowBand
        ? state.targetBands[i] > state.bands[i]
          ? 320
          : 110
        : state.targetBands[i] > state.bands[i]
          ? 120
          : 45;
    const blend = 1 - Math.exp(-delta * rate);
    const value =
      state.bands[i] + (state.targetBands[i] - state.bands[i]) * blend;
    values.push(value);
    maxDifference = Math.max(
      maxDifference,
      Math.abs(state.targetBands[i] - value),
    );
  }
  state.bands = maxDifference < 0.002 ? state.targetBands : values;
  state.interpolating = maxDifference >= 0.002;
  if (!state.interpolating && state.decaying) {
    state.decaying = false;
    state.bands = [];
    state.targetBands = [];
  }
  state.hasEnergy = state.bands.some((value) => value > 0.002);
}

function seededBands(count, seed) {
  return Array.from(
    { length: count },
    (_, i) => (Math.sin((i + 1) * (seed + 7) * 0.321) + 1) * 0.5,
  );
}

test("interpolation preserves 120 Hz attack, release, decay and energy values", () => {
  const advance = qmlFunction("advanceBands");
  for (const frameTime of [1 / 120, 1 / 144, 1 / 60, 0.031, 0.08]) {
    for (const decaying of [false, true]) {
      const initial = seededBands(96, 5);
      const target = decaying ? Array(96).fill(0) : seededBands(96, 31);
      const state = {
        bands: initial.slice(),
        targetBands: target.slice(),
        frameA: [],
        frameB: [],
        decaying,
        interpolating: true,
        lowHz: 20,
        highHz: 20000,
        hasEnergy: true,
      };
      const reference = {
        bands: initial.slice(),
        targetBands: target.slice(),
        decaying,
        interpolating: true,
        lowHz: 20,
        highHz: 20000,
      };
      for (let frame = 0; frame < 70; frame++) {
        advance(state, frameTime);
        referenceAdvance(reference, Math.min(frameTime, 0.05));
        assert.equal(state.bands.length, reference.bands.length);
        assert.equal(state.interpolating, reference.interpolating);
        assert.equal(state.decaying, reference.decaying);
        assert.equal(state.hasEnergy, reference.hasEnergy);
        for (let i = 0; i < state.bands.length; i++)
          assert.ok(
            Math.abs(state.bands[i] - reference.bands[i]) < 1e-12,
            `band ${i}, frame ${frame}`,
          );
      }
    }
  }
});

test("active animation reuses two buffers without producing identical frame identities", () => {
  const advance = qmlFunction("advanceBands");
  const state = {
    bands: Array(96).fill(0),
    targetBands: Array(96).fill(1),
    frameA: [],
    frameB: [],
    decaying: false,
    interpolating: true,
    lowHz: 20,
    highHz: 20000,
    hasEnergy: false,
  };
  const seen = [];
  for (let frame = 0; frame < 3; frame++) {
    advance(state, 0.001);
    seen.push(state.bands);
  }
  assert.equal(seen[0], seen[2]);
  assert.notEqual(seen[0], seen[1]);
  assert.equal(state.frameA.length, 96);
  assert.equal(state.frameB.length, 96);
});

test("prewarmed visualizers suspend hidden work without changing displayed band counts", () => {
  const bars = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/SpectrumBars.qml",
    ),
    "utf8",
  );
  const curve = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/SpectrumCurve.qml",
    ),
    "utf8",
  );
  assert.match(bars, /rendering: enabled && visible && opacity > 0/);
  assert.match(bars, /if \(!rendering\)\s*return \[\];/);
  assert.match(bars, /const values = spectrum\.bands;/);
  assert.match(
    bars,
    /Math\.pow\(Math\.max\(0, Math\.min\(1, peak\)\), 0\.88\)/,
  );
  assert.match(
    curve,
    /!root\.enabled \|\| !root\.visible \|\| root\.opacity <= 0/,
  );
});
