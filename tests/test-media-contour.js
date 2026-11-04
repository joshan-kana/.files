const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { test } = require("node:test");

const context = vm.createContext({ Math, Number, Infinity, Array });
vm.runInContext(
  fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/FrameGeometry.js",
    ),
    "utf8",
  ),
  context,
);
const squircle = {
  progress(t) {
    return t;
  },
  cornerPoint(cx, cy, r, a, exp) {
    return {
      x: cx + r * Math.sign(Math.cos(a)) * Math.abs(Math.cos(a)) ** (2 / exp),
      y: cy + r * Math.sign(Math.sin(a)) * Math.abs(Math.sin(a)) ** (2 / exp),
    };
  },
};
const contour = (islands) =>
  context.contour(
    1920,
    1080,
    24,
    50,
    4.5,
    islands,
    null,
    [],
    squircle,
    null,
    null,
    false,
  );

const main = {
  x: 230,
  y: 12,
  width: 280,
  height: 56,
  visible: true,
  interactionGroup: "media",
};
const playback = {
  x: 510,
  y: 12,
  width: 54,
  height: 56,
  visible: true,
  interactionGroup: "media",
};

test("adjacent media targets preserve exactly the unsplit frame silhouette", () => {
  const combined = contour([
    { x: 230, y: 12, width: 334, height: 56, visible: true },
  ]);
  const divided = contour([main, playback]);
  assert.equal(divided.inner, combined.inner);
  assert.equal(divided.fill, combined.fill);
  assert.equal(divided.hoverFill, "");
  assert.equal(divided.pressedFill, "");
});

test("each target highlights only its own portion of the connected notch", () => {
  const left = contour([{ ...main, hovered: true }, playback]);
  const right = contour([main, { ...playback, hovered: true }]);
  assert.match(left.hoverFill, /L510 68 L510 24 Z/);
  assert.match(right.hoverFill, /^M510 24 L510 68 /);
  assert.notEqual(left.hoverFill, right.hoverFill);
  assert.equal(left.inner, right.inner);
});

test("main press and playback hover use separate fill channels", () => {
  const result = contour([
    { ...main, pressed: true },
    { ...playback, hovered: true },
  ]);
  assert.ok(result.pressedFill.length > 20);
  assert.ok(result.hoverFill.length > 20);
  assert.ok(!result.pressedFill.includes("NaN"));
  assert.ok(!result.hoverFill.includes("NaN"));
});

test("narrow and overlapping islands keep a finite merged contour", () => {
  for (const width of [165, 206, 310, 458]) {
    const first = { ...main, width: width - 54 };
    const second = { ...playback, x: first.x + first.width };
    const result = contour([
      first,
      second,
      { x: 490, y: 12, width: 220, height: 580, visible: true },
    ]);
    assert.ok(result.inner.startsWith("M"));
    assert.ok(!result.inner.includes("NaN"));
    assert.ok(!result.hoverFill.includes("NaN"));
  }
});
