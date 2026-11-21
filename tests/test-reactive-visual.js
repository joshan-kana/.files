const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const theme = read("qml/Theme.qml");
const frame = read("qml/DesktopFrame.qml");
const renderer = read("visuals/plugin.cpp");

const expression = (name) => {
  const match = theme.match(
    new RegExp(`function ${name}\\([^)]*\\): color \\{([\\s\\S]*?)\\n    \\}`),
  );
  assert.ok(match, `${name} belongs to the shared Theme`);
  return match[1];
};
const blend = (base, accent, weight) => ({
  r: base.r + (accent.r - base.r) * weight,
  g: base.g + (accent.g - base.g) * weight,
  b: base.b + (accent.b - base.b) * weight,
});
const red = { r: 0.98, g: 0.3, b: 0.24 };
const blue = { r: 0.24, g: 0.57, b: 0.98 };
const cyan = { r: 0.32, g: 0.85, b: 0.96 };
const background = { r: 0.07, g: 0.075, b: 0.08 };
const spectrumColor = (position) =>
  position <= 0.5
    ? blend(red, blue, position * 2)
    : blend(blue, cyan, (position - 0.5) * 2);
const reactiveColorBody = new Function(
  "base",
  "position",
  "musicReactiveWash",
  "blend",
  "spectrumColor",
  expression("reactiveColor"),
);
const frameColorBody = new Function(
  "position",
  "reactiveColor",
  "background",
  "Qt",
  "shellGlassEnabled",
  "glassOpacity",
  expression("reactiveFrameColor"),
);
const colorAt = (
  position,
  energy,
  beat,
  enabled = true,
  glass = false,
  opacity = 0.7,
) => {
  const wash = enabled ? Math.min(0.42, energy * 0.58 + beat * 0.14) : 0;
  const reactiveColor = (base, p) =>
    reactiveColorBody(base, p, wash, blend, spectrumColor);
  return frameColorBody(
    position,
    reactiveColor,
    background,
    { rgba: (r, g, b, a) => ({ r, g, b, a }) },
    glass,
    opacity,
  );
};
const contrast = (a, b) =>
  Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);

test("the original spectrum gradient transitions red to blue to cyan, without per-band flashes", () => {
  const left = colorAt(0, 0.75, 0.2);
  const middle = colorAt(0.5, 0.75, 0.2);
  const right = colorAt(1, 0.75, 0.2);
  assert.ok(left.r > left.b && left.r > left.g);
  assert.ok(middle.b > middle.r);
  assert.ok(right.g > middle.g && right.b > right.r);
  assert.match(
    theme,
    /musicReactiveWash: musicReactiveEnabled \? Math\.min\(0\.42,/,
  );
  assert.doesNotMatch(
    theme,
    /musicReactiveBands|musicReactiveImpulses|reactiveSpectrumColor/,
  );
  assert.doesNotMatch(
    renderer,
    /gradientBands_|gradientImpulses_|gradientMotionChanged/,
  );
});

test("the first gradient uses a common intensity envelope and preserves silence and glass alpha", () => {
  for (const p of [0, 0.25, 0.5, 0.75, 1]) {
    assert.deepEqual(colorAt(p, 0, 0), { ...background, a: 1 });
    assert.deepEqual(colorAt(p, 1, 1, false), { ...background, a: 1 });
    const baseline = colorAt(p, 0.1, 0);
    const accent = colorAt(p, 0.8, 0.9);
    assert.ok(contrast(baseline, accent) > 0.1);
    assert.equal(accent.a, 1);
    assert.equal(colorAt(p, 0.8, 0.9, true, true, 0.37).a, 0.37);
    assert.deepEqual(colorAt(p, 0.8, 0.9), colorAt(p, 0.8, 0.9));
  }
});

test("the connected frame uses the original five colour stops and keeps its clipped geometry", () => {
  assert.match(frame, /gradientInset: Math\.max\(0\.005,/);
  assert.match(frame, /position: output\.gradientInset/);
  assert.match(frame, /position: 1 - output\.gradientInset/);
  for (const p of ["0", "0.5", "1"])
    assert.ok(frame.includes(`reactiveFrameColor(${p})`));
  assert.equal((frame.match(/reactiveFrameColor\(/g) || []).length, 5);
  assert.match(frame, /fillRule: Qt\.OddEvenFill/);
  assert.match(frame, /strokeColor: frame\.reactiveBorder/);
  assert.doesNotMatch(frame, /FrameRibbonItem|FrameFillItem/);
});
