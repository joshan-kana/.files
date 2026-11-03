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
  progress(t, exponent) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const power = exponent / 2;
    const a = t ** power;
    return a / (a + (1 - t) ** power);
  },
  cornerPoint(cx, cy, radius, angle, exponent) {
    return {
      x:
        cx +
        radius *
          Math.sign(Math.cos(angle)) *
          Math.abs(Math.cos(angle)) ** (2 / exponent),
      y:
        cy +
        radius *
          Math.sign(Math.sin(angle)) *
          Math.abs(Math.sin(angle)) ** (2 / exponent),
    };
  },
};

function frame(exponent, islands = []) {
  return context.contour(
    1920,
    1080,
    26,
    62,
    exponent,
    islands,
    null,
    [],
    squircle,
    null,
    null,
  );
}

function cubicPoint(start, controls, t) {
  const a = 1 - t;
  return [
    a ** 3 * start[0] +
      3 * a ** 2 * t * controls[0] +
      3 * a * t ** 2 * controls[2] +
      t ** 3 * controls[4],
    a ** 3 * start[1] +
      3 * a ** 2 * t * controls[1] +
      3 * a * t ** 2 * controls[3] +
      t ** 3 * controls[5],
  ];
}

test("frame uses a compact cubic contour while retaining the full trace resolution", () => {
  const result = frame(4.5);
  assert.equal((result.inner.match(/C/g) || []).length, 4);
  assert.ok(
    result.inner.length < 500,
    `unexpected path length ${result.inner.length}`,
  );
  assert.ok(result.points.length > 80);
  assert.ok(result.length > 5000);
});

test("cubic frame contours retain the same diagonal and smooth superellipse profile", () => {
  const radius = 62;
  const center = [1920 - 26 - radius, 26 + radius];
  const start = [center[0], center[1] - radius];
  for (const exponent of [2, 3, 4.5, 6, 8, 12]) {
    const result = frame(exponent);
    const match = result.inner.match(
      /C(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)/,
    );
    assert.ok(match, `missing top-right cubic for exponent ${exponent}`);
    const controls = match.slice(1).map(Number);
    assert.ok(Math.abs(controls[4] - center[0] - radius) < 0.001);
    assert.ok(Math.abs(controls[5] - center[1]) < 0.001);
    let maxError = 0;
    for (let i = 0; i <= 100; i++) {
      const p = cubicPoint(start, controls, i / 100);
      const x = Math.abs((p[0] - center[0]) / radius);
      const y = Math.abs((p[1] - center[1]) / radius);
      maxError = Math.max(
        maxError,
        Math.abs((x ** exponent + y ** exponent) ** (1 / exponent) - 1),
      );
    }
    assert.ok(
      maxError < 0.012,
      `${exponent}: relative contour error ${maxError}`,
    );
  }
});

test("attached hover contour reuses curved frame segments", () => {
  const active = frame(4.5, [
    { x: 560, y: 12, width: 230, height: 50, visible: true, hovered: true },
  ]);
  assert.ok(active.hoverFill.startsWith("M"));
  assert.ok(active.hoverFill.includes("C"));
  assert.ok(active.inner.includes("C"));
  assert.equal(active.pressedFill, "");
});

test("overlapping shallow bar islands do not inherit the full gallery depth", () => {
  const media = { x: 300, y: 26, width: 458, height: 40, visible: true };
  const gallery = { x: 720, y: 26, width: 1120, height: 750, visible: true };
  const result = context.contour(
    2560,
    1440,
    26,
    62,
    4.5,
    [media],
    gallery,
    [],
    squircle,
    null,
    null,
  );
  assert.ok(
    result.points.some((p) => p.x > 310 && p.x < 680 && p.y > 61 && p.y < 68),
    "shallow media island must retain its own bottom",
  );
  assert.ok(
    result.points.some(
      (p) => p.x > 750 && p.x < 1800 && p.y > 771 && p.y < 780,
    ),
    "deep gallery must retain its own bottom",
  );
  assert.equal(
    result.points.some((p) => p.x > 350 && p.x < 660 && p.y > 130 && p.y < 850),
    false,
    "gallery must not create a tall phantom panel beneath media",
  );
});

test("overlap transitions preserve finite smooth corners in both directions", () => {
  for (const offset of [0, 40, 70, 100]) {
    const gallery = {
      x: 720 - offset,
      y: 26,
      width: 1120,
      height: 750,
      visible: true,
    };
    const left = { x: 300, y: 26, width: 458, height: 40, visible: true };
    const right = { x: 1700, y: 26, width: 458, height: 40, visible: true };
    const result = context.contour(
      2560,
      1440,
      26,
      62,
      4.5,
      [left, right],
      gallery,
      [],
      squircle,
      null,
      null,
    );
    assert.equal(/NaN|Infinity/.test(result.inner), false);
    assert.ok(
      (result.inner.match(/C/g) || []).length >= 12,
      "joined vertical transitions must use curved corners",
    );
    assert.ok(
      result.points.every(
        (point) => Number.isFinite(point.x) && Number.isFinite(point.y),
      ),
    );
    assert.ok(
      result.points.every(
        (point) =>
          point.x >= 0 && point.x <= 2560 && point.y >= 0 && point.y <= 1440,
      ),
    );
  }
});
