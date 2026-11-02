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

test("tapered glow follows real contour vertices with batched raster strokes", () => {
  const strokes = [];
  const segments = [];
  let from = null;
  let pending = [];
  const ctx = {
    clearRect() {},
    beginPath() {
      pending = [];
    },
    moveTo(x, y) {
      from = { x, y };
    },
    lineTo(x, y) {
      const to = { x, y };
      pending.push({ from, to });
      segments.push({ from, to });
      from = to;
    },
    stroke() {
      strokes.push({
        segments: pending.slice(),
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
    2,
    120,
    90,
  );
  const strokesPerLayer = strokes.length / 4;
  assert.equal(strokes.length % 4, 0);
  assert.ok(strokesPerLayer > 8 && strokesPerLayer <= 24);
  assert.ok(
    segments.length > strokes.length * 1.2,
    "adjacent segments should share one drawing pass",
  );
  assert.ok(
    segments.every(
      ({ from, to }) => Math.hypot(to.x - from.x, to.y - from.y) <= 8.01,
    ),
    "real contour segments must not shortcut corners",
  );
  assert.ok(
    segments.some(
      ({ from, to }) =>
        Math.abs(from.x - 110) < 0.001 || Math.abs(to.x - 110) < 0.001,
    ),
  );
  const layer = (i) =>
    strokes.slice(i * strokesPerLayer, (i + 1) * strokesPerLayer);
  for (let i = 0; i < 4; i++) {
    assert.ok(
      layer(i)[0].alpha < layer(i).at(-1).alpha,
      "tail must fade into brighter head",
    );
    assert.ok(layer(i)[0].width < layer(i).at(-1).width, "tail must narrow");
  }
  assert.ok(layer(0).at(-1).width > layer(1).at(-1).width);
  assert.ok(layer(1).at(-1).width > layer(2).at(-1).width);
  assert.ok(layer(2).at(-1).width > layer(3).at(-1).width);
  assert.ok(layer(0).at(-1).alpha < layer(3).at(-1).alpha);
});

test("long frame trace batches raster strokes instead of repainting every tiny segment", () => {
  const path = [{ x: 0, y: 0, at: 0 }];
  for (let x = 5; x <= 5000; x += 5) path.push({ x, y: 0, at: x });
  let strokes = 0,
    lineSegments = 0;
  const ctx = {
    clearRect() {},
    beginPath() {},
    moveTo() {},
    lineTo() {
      lineSegments++;
    },
    stroke() {
      strokes++;
    },
  };
  trace.paint(
    ctx,
    path,
    5000,
    0.8,
    0.15,
    { r: 0.2, g: 0.5, b: 0.9 },
    2,
    5100,
    100,
  );
  assert.ok(lineSegments > 400);
  assert.ok(
    strokes <= 100,
    `the four glow layers must not exceed 100 strokes, saw ${strokes}`,
  );
  assert.ok(lineSegments > strokes * 4);
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

test("bounded frame trace keeps its full halo inside a quantized tile", () => {
  const points = [
    { x: 30, y: 30, at: 0 },
    { x: 1800, y: 30, at: 1770 },
    { x: 1800, y: 970, at: 2710 },
    { x: 30, y: 970, at: 4480 },
    { x: 30, y: 30, at: 5420 },
  ];
  const bounds = trace.traceBounds(points, 5420, 0.25, 0.1, 24, 1920, 1080);
  assert.ok(
    bounds.width < 1920 || bounds.height < 1080,
    "animation must not repaint the entire monitor",
  );
  assert.equal(bounds.x % 64, 0);
  assert.equal(bounds.y % 64, 0);
  for (const point of bounds.samples) {
    assert.ok(
      point.x >= bounds.x + 20 && point.x <= bounds.x + bounds.width - 20,
    );
    assert.ok(
      point.y >= bounds.y + 20 && point.y <= bounds.y + bounds.height - 20,
    );
  }
  assert.ok(bounds.samples.length > 20);
});

test("bounded stroke uses local coordinates without changing the traced path", () => {
  const path = [
    { x: 30, y: 30, at: 0 },
    { x: 950, y: 30, at: 920 },
    { x: 950, y: 500, at: 1390 },
    { x: 30, y: 500, at: 2310 },
    { x: 30, y: 30, at: 2780 },
  ];
  const bounds = trace.traceBounds(path, 2780, 0.45, 0.1, 24, 1000, 550);
  let segments = 0;
  const ctx = {
    clearRect() {},
    beginPath() {},
    moveTo(x, y) {
      this.from = [x, y];
    },
    lineTo(x, y) {
      assert.ok(x >= 0 && x <= bounds.width && y >= 0 && y <= bounds.height);
      segments++;
    },
    stroke() {},
    arc() {},
    fill() {},
  };
  trace.paint(
    ctx,
    path,
    2780,
    0.45,
    0.1,
    { r: 0.3, g: 0.6, b: 0.9 },
    2,
    bounds.width,
    bounds.height,
    bounds.x,
    bounds.y,
    bounds,
  );
  assert.ok(segments > 30);
});
