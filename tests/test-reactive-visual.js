const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const theme = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/qml/Theme.qml"),
  "utf8",
);
const match = theme.match(
  /function reactiveFrameColor\(position: real, illuminated: bool\): color \{([\s\S]*?)\n    \}/,
);
assert.ok(match, "evaluate the actual QML frame-colour expression");
const evaluate = new Function(
  "position",
  "illuminated",
  "musicReactiveBands",
  "musicReactiveKick",
  "background",
  "spectrumColor",
  "blend",
  "Qt",
  "shellGlassEnabled",
  "glassOpacity",
  match[1],
);
const background = { r: 0.07, g: 0.075, b: 0.08 };
const colors = [
  { r: 0.98, g: 0.32, b: 0.26 },
  { r: 0.24, g: 0.57, b: 0.98 },
  { r: 0.35, g: 0.86, b: 0.96 },
];
const blend = (a, b, t) => ({
  r: a.r + (b.r - a.r) * t,
  g: a.g + (b.g - a.g) * t,
  b: a.b + (b.b - a.b) * t,
});
const spectrumColor = (position) => {
  const scaled = Math.max(0, Math.min(1, position)) * 2;
  const i = Math.min(1, Math.floor(scaled));
  return blend(colors[i], colors[i + 1], scaled - i);
};
const steady = [0.13, 0.24, 0.22, 0.17, 0.15, 0.14, 0.12, 0.1, 0.09];
const frameColor = (
  position,
  levels = steady,
  kick = 0,
  enabled = true,
  glass = false,
) =>
  evaluate(
    position,
    enabled,
    levels,
    kick,
    background,
    spectrumColor,
    blend,
    { rgba: (r, g, b, a) => ({ r, g, b, a }) },
    glass,
    0.35,
  );
const difference = (a, b) =>
  Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);

test("original Stylix red, blue and cyan survive the reactive spectrum treatment", () => {
  const left = frameColor(0),
    middle = frameColor(0.5),
    right = frameColor(1);
  assert.ok(left.r > left.g && left.r > left.b);
  assert.ok(middle.b > middle.r);
  assert.ok(right.b > right.r);
});

test("identical audio envelopes produce identical pixels, with no autonomous animation", () => {
  for (const p of [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1])
    assert.deepEqual(frameColor(p, steady), frameColor(p, [...steady]));
  assert.doesNotMatch(theme, /musicReactiveFlow|flowPhase|Math\.sin\(phase/);
});

test("actual kick attacks illuminate the low-mid zone, not the whole shell", () => {
  const kickBands = [0.13, 0.91, 0.83, 0.46, 0.15, 0.14, 0.12, 0.1, 0.09];
  const changes = Array.from({ length: 9 }, (_, i) =>
    difference(frameColor(i / 8), frameColor(i / 8, kickBands, 0.9)),
  );
  assert.ok(
    changes[1] > 0.23,
    "kick must be visibly stronger than a tiny RGB delta",
  );
  assert.ok(changes[2] > 0.18);
  assert.ok(changes[1] > changes[6] * 5);
  assert.ok(changes[2] > changes[8] * 5);
});

test("melody and cymbals illuminate middle/right zones without pumping sub-bass", () => {
  const melody = [0.13, 0.24, 0.22, 0.45, 0.82, 0.88, 0.82, 0.67, 0.54];
  const deltas = Array.from({ length: 9 }, (_, i) =>
    difference(frameColor(i / 8), frameColor(i / 8, melody)),
  );
  assert.ok(deltas[5] > 0.2);
  assert.ok(deltas[6] > 0.2);
  assert.ok(deltas[0] < 0.001, "treble does not pump left-most sub-bass");
});

test("paused music has no animated field and preserves actual pane opacity", () => {
  const silent = Array(9).fill(0);
  for (const p of [0, 0.25, 0.5, 0.75, 1]) {
    assert.deepEqual(frameColor(p, silent), frameColor(p, [...silent]));
    assert.equal(frameColor(p, silent, 0, true, true).a, 0.35);
    assert.deepEqual(frameColor(p, silent, 0, false), { ...background, a: 1 });
  }
});
