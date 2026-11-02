const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

const source = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/qml/OutlineTrace.js"),
  "utf8",
);
const trace = vm.createContext({ Math });
vm.runInContext(source, trace);
const points = [
  { x: 10, y: 10, at: 0 },
  { x: 110, y: 10, at: 100 },
  { x: 110, y: 80, at: 170 },
  { x: 10, y: 80, at: 270 },
  { x: 10, y: 10, at: 340 },
];

test("tapered glow follows the contour vertices without corner shortcuts", () => {
  const strokes = [];
  let from = null;
  let to = null;
  const ctx = {
    clearRect() {},
    beginPath() {},
    moveTo(x, y) {
      from = { x, y };
    },
    lineTo(x, y) {
      to = { x, y };
    },
    stroke() {
      strokes.push({
        from,
        to,
        width: this.lineWidth,
        alpha: Number(this.strokeStyle.match(/, ([\d.]+)\)$/)[1]),
      });
    },
  };
  trace.paint(
    ctx,
    points,
    340,
    0.7,
    0.65,
    { r: 0.2, g: 0.5, b: 0.9 },
    3,
    120,
    90,
  );
  const eachLayer = strokes.length / 4;
  assert.ok(eachLayer > 20);
  assert.equal(strokes.length % 4, 0);
  for (let layer = 0; layer < 4; layer++) {
    assert.ok(
      strokes[layer * eachLayer].alpha <
        strokes[(layer + 1) * eachLayer - 1].alpha,
    );
  }
  assert.ok(strokes[0].width > strokes[eachLayer].width);
  assert.ok(strokes[eachLayer].width > strokes[2 * eachLayer].width);
  assert.ok(strokes[2 * eachLayer].width > strokes[3 * eachLayer].width);
  assert.ok(strokes[0].alpha < strokes[eachLayer].alpha);
  assert.ok(strokes[eachLayer].alpha < strokes[2 * eachLayer].alpha);
  assert.ok(strokes[2 * eachLayer].alpha < strokes[3 * eachLayer].alpha);
  assert.ok(strokes[0].alpha < 0.03);
  assert.ok(strokes[eachLayer].alpha < 0.05);
  assert.ok(strokes[2 * eachLayer].alpha < 0.08);
  assert.ok(
    strokes.every(
      ({ from, to }) => Math.hypot(to.x - from.x, to.y - from.y) < 8.01,
    ),
    "Every highlighted segment must remain on the native contour rather than shortcutting corners",
  );
  assert.ok(
    strokes.some(
      ({ from, to }) =>
        Math.abs(from.x - 110) < 0.001 || Math.abs(to.x - 110) < 0.001,
    ),
  );
});

test("closing segment interpolates continuously instead of jumping to the origin", () => {
  const openContour = points.slice(0, -1);
  const at = trace.atDistance(openContour, 340, 305);
  assert.ok(Math.abs(at.x - 10) < 0.001);
  assert.ok(Math.abs(at.y - 45) < 0.001);
});

test("inactive and invalid outlines do not draw strokes", () => {
  let calls = 0;
  trace.paint(
    {
      clearRect() {},
      stroke() {
        calls++;
      },
    },
    [],
    0,
    0,
    0.1,
    {},
    3,
    100,
    50,
  );
  assert.equal(calls, 0);
});
