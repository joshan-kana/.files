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
  progress(value, exponent) {
    if (value <= 0) return 0;
    if (value >= 1) return 1;
    const power = exponent / 2;
    const first = value ** power;
    return first / (first + (1 - value) ** power);
  },
  cornerPoint(cx, cy, radius, angle, exponent) {
    const x = Math.cos(angle);
    const y = Math.sin(angle);
    return {
      x: cx + radius * Math.sign(x) * Math.abs(x) ** (2 / exponent),
      y: cy + radius * Math.sign(y) * Math.abs(y) ** (2 / exponent),
    };
  },
};
const contour = (...args) =>
  context.contour(...args.slice(0, 8), squircle, args[8], args[9], args[10]);

function check(result, width, height) {
  assert.ok(result.length > 0);
  assert.match(result.inner, /^M[\d.]+ [\d.]+/);
  assert.match(result.fill, /Z M/);
  assert.ok(result.points.length >= 32);
  let previous = -1;
  for (const point of result.points) {
    assert.ok(Number.isFinite(point.x) && Number.isFinite(point.y));
    assert.ok(point.x >= -0.01 && point.x <= width + 0.01);
    assert.ok(point.y >= -0.01 && point.y <= height + 0.01);
    assert.ok(point.at >= previous);
    previous = point.at;
  }
  assert.ok(result.length >= previous);
}

test("idle frame keeps exact connected contour without loading-trace sampling", () => {
  const island = {
    x: 220,
    y: 10,
    width: 150,
    height: 65,
    visible: true,
    hovered: true,
  };
  const hub = { x: 490, y: 12, width: 870, height: 520, visible: true };
  const dock = { x: 1560, y: 90, width: 330, height: 180, visible: true };
  const osd = { x: 790, y: 880, width: 330, height: 72, visible: true };
  for (const exponent of [2, 4.5, 8, 12]) {
    const inputs = [1920, 1080, 26, 62, exponent, [island], hub, [dock], osd];
    const traced = contour(...inputs, undefined, true);
    const idle = contour(...inputs, undefined, false);
    for (const key of ["inner", "fill", "hoverFill", "pressedFill"])
      assert.equal(idle[key], traced[key], key);
    assert.ok(idle.points.length < traced.points.length / 2);
    assert.ok(traced.length >= idle.length);
  }
});

test("hub morph layout remains independent of the live silhouette size", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const hub = fs.readFileSync(
    path.join(root, "ShellExpansionHost.qml"),
    "utf8",
  );
  const surface = fs.readFileSync(
    path.join(root, "SquircleSurface.qml"),
    "utf8",
  );
  const frame = fs.readFileSync(path.join(root, "DesktopFrame.qml"), "utf8");
  assert.match(hub, /contentLayoutWidth:.*host\.contentWidth/);
  assert.match(hub, /contentLayoutHeight:.*host\.contentHeight/);
  assert.match(surface, /property real contentLayoutWidth: width/);
  assert.match(surface, /property real contentLayoutHeight: height/);
  assert.match(surface, /width: root\.contentLayoutWidth/);
  assert.match(surface, /height: root\.contentLayoutHeight/);
  assert.match(
    frame,
    /onGeometryInputsChanged: Qt\.callLater\(output\.rebuildGeometry\)/,
  );
  assert.match(frame, /output\.busyHere/);
});

test("frame disabled and degenerate displays have no contour", () => {
  for (const dimensions of [
    [0, 1080],
    [1280, 0],
    [1280, 720, 0],
  ]) {
    const frame = contour(
      dimensions[0],
      dimensions[1],
      dimensions[2] === undefined ? 17 : dimensions[2],
      30,
      4.5,
      [],
      null,
      [],
    );
    assert.equal(frame.length, 0);
  }
});

test("all frame and attachment modes remain inside their monitor", () => {
  const displays = [
    [3840, 2160],
    [2560, 1440],
    [1920, 1080],
    [1280, 720],
    [350, 240],
  ];
  for (const [width, height] of displays) {
    const islands = [
      { x: 30, y: 10, width: 110, height: 48, visible: true },
      { x: width / 2 - 120, y: 10, width: 240, height: 48, visible: true },
      { x: width - 170, y: 10, width: 135, height: 48, visible: true },
    ];
    const hub = {
      x: Math.max(20, width / 2 - 350),
      y: 12,
      width: Math.min(width - 40, 700),
      height: Math.min(height - 50, 530),
      visible: true,
    };
    const docks = [
      { x: width - 390, y: 90, width: 380, height: 170, visible: true },
      { x: width - 390, y: 272, width: 380, height: 170, visible: true },
    ];
    for (const bar of [false, true]) {
      for (const expanded of [false, true]) {
        for (const notifications of [false, true]) {
          const result = contour(
            width,
            height,
            17,
            30,
            4.5,
            bar ? islands : [],
            expanded ? hub : null,
            notifications ? docks : [],
          );
          check(result, width, height);
        }
      }
    }
  }
});

test("overlapping and screen-clamped attachments yield finite paths", () => {
  for (let n = 0; n < 200; n++) {
    const width = 150 + ((n * 137) % 3000);
    const height = 180 + ((n * 83) % 1600);
    const thickness = 1 + (n % 36);
    const radius = 12 + (n % 100);
    const islands = Array.from({ length: n % 7 }, (_, i) => ({
      x: i * 115 - 60 + (n % 35),
      y: n % 25,
      width: 160 + ((n * i) % 190),
      height: 45 + ((i * n) % 120),
      visible: true,
    }));
    const docks = [
      {
        x: width - 440,
        y: height * 0.1,
        width: 430,
        height: 180,
        visible: true,
      },
      {
        x: width - 440,
        y: height * 0.1 + 170,
        width: 430,
        height: 200,
        visible: true,
      },
      {
        x: width - 440,
        y: height * 0.6,
        width: 430,
        height: 170,
        visible: n % 2 === 0,
      },
    ];
    check(
      contour(width, height, thickness, radius, 4.5, islands, null, docks),
      width,
      height,
    );
  }
});

test("centered bottom OSD shares the frame contour without a side dock", () => {
  const width = 1920;
  const height = 1080;
  const osd = {
    x: (width - 370) / 2,
    y: height - 26 - 76,
    width: 370,
    height: 76,
    visible: true,
  };
  const plain = contour(width, height, 26, 62, 4.5, [], null, [], null);
  const framed = contour(width, height, 26, 62, 4.5, [], null, [], osd);
  check(framed, width, height);
  assert.ok(framed.length > plain.length);
  assert.ok(
    framed.points.some(
      (point) =>
        point.x > osd.x &&
        point.x < osd.x + osd.width &&
        Math.abs(point.y - osd.y) < 0.01,
    ),
  );
  // The OSD joins the bottom. The right edge should remain unchanged.
  const rightmost = Math.max(...framed.points.map((point) => point.x));
  assert.equal(rightmost, width - 26);
});

test("overlapping bottom-centered attachments have one finite envelope", () => {
  const width = 2560,
    height = 1440;
  const dock = [
    { x: 950, y: 1310, width: 370, height: 104, visible: true },
    { x: 1200, y: 1318, width: 370, height: 96, visible: true },
  ];
  const frame = contour(width, height, 26, 62, 4.5, [], null, [], dock);
  check(frame, width, height);
  assert.ok(frame.length > 0);
});

test("connected island hover fills the exact top contour, never an independent pill", () => {
  const w = 1920,
    h = 1080;
  const hover = {
    x: 560,
    y: 12,
    width: 230,
    height: 50,
    visible: true,
    hovered: true,
  };
  const active = contour(w, h, 26, 62, 4.5, [hover], null, [], null);
  const inactive = contour(
    w,
    h,
    26,
    62,
    4.5,
    [{ ...hover, hovered: false }],
    null,
    [],
    null,
  );
  check(active, w, h);
  assert.match(active.hoverFill, /^M[\d.]+ [\d.]+ C/);
  assert.equal(inactive.hoverFill, "");
  assert.equal(active.inner, inactive.inner);
  assert.ok(active.hoverFill.includes("Z"));
});

test("bottom OSD reveals continuously from the frame edge", () => {
  const w = 1920,
    h = 1080,
    t = 26;
  const plain = contour(w, h, t, 62, 4.5, [], null, [], null);
  let previous = 0;
  for (const ratio of [0.01, 0.1, 0.25, 0.5, 0.75, 1]) {
    const height = 76 * ratio;
    const osd = {
      x: (w - 370) / 2,
      y: h - t - height,
      width: 370,
      height,
      visible: true,
    };
    const shape = contour(w, h, t, 62, 4.5, [], null, [], osd);
    check(shape, w, h);
    assert.ok(shape.length >= plain.length - 1);
    const top = Math.min(
      ...shape.points
        .filter((p) => p.x > osd.x && p.x < osd.x + osd.width)
        .map((p) => p.y),
    );
    assert.ok(top <= osd.y + 0.01 && top >= osd.y - 0.01);
    assert.ok(plain.length + previous >= 0);
    previous = shape.length - plain.length;
  }
});

test("notification attachments expand from the right edge without invalid corners", () => {
  const w = 1920,
    h = 1080,
    t = 26;
  for (const n of [0.01, 0.2, 0.5, 0.8, 1]) {
    const width = 440,
      height = 170 * n;
    const dock = {
      x: w - t - width,
      y: 170 + 170 * (1 - n),
      width,
      height,
      visible: true,
    };
    check(contour(w, h, t, 62, 4.5, [], null, [dock], null), w, h);
  }
});

test("short connected notches never fold their stroke across a widget", () => {
  const width = 1920,
    height = 1080,
    thickness = 26,
    radius = 62;
  const bottom = height - thickness;
  const checkVertical = (points, x, ascending) => {
    for (let i = 1; i < points.length; ++i) {
      const previous = points[i - 1];
      const current = points[i];
      if (Math.abs(previous.x - x) > 0.001 || Math.abs(current.x - x) > 0.001)
        continue;
      if (ascending)
        assert.ok(
          current.y + 0.001 >= previous.y,
          "top lobe side must not reverse direction",
        );
      else
        assert.ok(
          current.y <= previous.y + 0.001,
          "bottom OSD side must not fold back through its content",
        );
    }
  };
  for (const depth of [2, 3, 8, 15, 25, 40, 50, 76]) {
    const osd = {
      x: 775,
      y: bottom - depth,
      width: 370,
      height: depth,
      visible: true,
    };
    const framedOsd = contour(
      width,
      height,
      thickness,
      radius,
      4.5,
      [],
      null,
      [],
      osd,
    );
    check(framedOsd, width, height);
    checkVertical(framedOsd.points, osd.x + osd.width, false);

    const topIsland = {
      x: 775,
      y: 10,
      width: 370,
      height: thickness + depth,
      visible: true,
    };
    const framedTop = contour(
      width,
      height,
      thickness,
      radius,
      4.5,
      [topIsland],
      null,
      [],
      null,
    );
    check(framedTop, width, height);
    checkVertical(framedTop.points, topIsland.x, true);
  }
});

test("connected press feedback uses the same contour as hover without double fill", () => {
  const frame = { x: 280, y: 26, width: 230, height: 52, visible: true };
  const pressed = contour(
    1920,
    1080,
    26,
    62,
    4.5,
    [{ ...frame, hovered: true, pressed: true }],
    null,
    [],
    null,
  );
  const hovered = contour(
    1920,
    1080,
    26,
    62,
    4.5,
    [{ ...frame, hovered: true, pressed: false }],
    null,
    [],
    null,
  );
  assert.equal(pressed.hoverFill, "");
  assert.match(pressed.pressedFill, /^M[\d.]+ [\d.]+/);
  assert.equal(pressed.pressedFill, hovered.hoverFill);
  assert.equal(hovered.pressedFill, "");
  assert.equal(pressed.inner, hovered.inner);
});

test("resize overlay joins the top frame without affecting side or bottom docks", () => {
  const resize = { x: 735, y: 70, width: 450, height: 200, visible: true };
  const expanded = contour(1920, 1080, 26, 62, 4.5, [], null, [], null, resize);
  check(expanded, 1920, 1080);
  const plain = contour(1920, 1080, 26, 62, 4.5, [], null, [], null);
  assert.notEqual(expanded.inner, plain.inner);
  assert.equal(expanded.hoverFill, "");
});

test("adjacent status islands remain distinct, with independent squircle shoulders", () => {
  for (const gap of [5, 12, 18, 26, 45]) {
    const separated = [
      { x: 1320, y: 26, width: 95, height: 38, visible: true },
      { x: 1415 + gap, y: 26, width: 155, height: 38, visible: true },
    ];
    const separate = contour(
      1920,
      1080,
      26,
      62,
      4.5,
      separated,
      null,
      [],
      null,
    );
    const one = contour(
      1920,
      1080,
      26,
      62,
      4.5,
      [
        {
          x: 1320,
          y: 26,
          width: 250 + gap,
          height: 38,
          visible: true,
        },
      ],
      null,
      [],
      null,
    );
    assert.notEqual(
      separate.inner,
      one.inner,
      "separate islands may not merge with gap " + gap,
    );
    // A visible top-edge segment must remain between the two notches.
    assert.ok(
      separate.points.some(
        (p, i, points) =>
          i > 1 && p.x > 1415 && p.x < 1415 + gap && Math.abs(p.y - 26) < 0.01,
      ),
      "gap should retain its own visible boundary " + gap,
    );
    check(separate, 1920, 1080);
  }
});

test("adjacent wells retain independent outer shoulders", () => {
  const oneSide = contour(
    1200,
    800,
    26,
    62,
    4.5,
    [
      { x: 130, y: 26, width: 150, height: 38, visible: true },
      { x: 292, y: 26, width: 180, height: 38, visible: true },
    ],
    null,
    [],
  );
  check(oneSide, 1200, 800);
  // The first well's left shoulder must not collapse simply because a second
  // well is only twelve logical pixels away on its right.
  assert.ok(
    oneSide.points.some(
      (p) => Math.abs(p.y - 26) < 0.01 && p.x > 106 && p.x < 116,
    ),
  );
  assert.ok(
    oneSide.points.some(
      (p) => Math.abs(p.y - 26) < 0.01 && p.x > 281 && p.x < 292,
    ),
  );
});

test("top and bottom outer corners use one shared squircle radius", () => {
  const radius = 62;
  const thickness = 26;
  const w = 2560,
    h = 1440;
  const frame = contour(
    w,
    h,
    thickness,
    radius,
    4.5,
    [
      {
        x: thickness + radius + 24,
        y: thickness,
        width: 66,
        height: 38,
        visible: true,
      },
      {
        x: w - thickness - radius - 24 - 220,
        y: thickness,
        width: 220,
        height: 38,
        visible: true,
      },
    ],
    null,
    [],
  );
  check(frame, w, h);
  // First point and the right-edge arrival are the starts of both top arcs;
  // the bottom edge and left-edge return must retain the identical radius.
  assert.equal(frame.points[0].x, thickness + radius);
  assert.ok(
    frame.points.some(
      (p) =>
        Math.abs(p.x - (w - thickness)) < 0.0001 &&
        Math.abs(p.y - (thickness + radius)) < 0.0001,
    ),
  );
  assert.ok(
    frame.points.some(
      (p) =>
        Math.abs(p.x - (w - thickness)) < 0.0001 &&
        Math.abs(p.y - (h - thickness - radius)) < 0.0001,
    ),
  );
  assert.ok(
    frame.points.some(
      (p) =>
        Math.abs(p.x - thickness) < 0.0001 &&
        Math.abs(p.y - (h - thickness - radius)) < 0.0001,
    ),
  );
});

test("nearby wells preserve a visible top bridge between their shoulder arcs", () => {
  const gap = 30;
  const firstRight = 1415;
  const segment = contour(
    1920,
    1080,
    26,
    62,
    4.5,
    [
      { x: 1320, y: 26, width: 95, height: 38, visible: true },
      { x: firstRight + gap, y: 26, width: 155, height: 38, visible: true },
    ],
    null,
    [],
    null,
  );
  const topBridge = segment.points.filter(
    (p) =>
      p.y >= 25.99 &&
      p.y <= 26.01 &&
      p.x > firstRight &&
      p.x < firstRight + gap,
  );
  assert.ok(
    topBridge.length >= 2,
    "each well must have its own separate shoulder",
  );
  assert.ok(
    topBridge.at(-1).x - topBridge[0].x > gap * 0.3,
    "the top frame must remain visible between separate status islands",
  );
});

test("end islands preserve complete contours beyond both outer corner tangents", () => {
  const thickness = 26;
  const radius = 62;
  const inset = thickness + radius + 24;
  const height = 50;
  const width = 2560;
  const endWidth = 230;
  const islands = [
    { x: inset, y: thickness, width: 66, height, visible: true },
    {
      x: width - inset - endWidth,
      y: thickness,
      width: endWidth,
      height,
      visible: true,
    },
  ];
  const shape = contour(width, 1440, thickness, radius, 4.5, islands, null, []);
  check(shape, width, 1440);
  const outerTangent = thickness + radius;
  const leftShoulder = inset - outerTangent;
  assert.ok(leftShoulder >= 20, "workspace must clear the full outer radius");
  assert.ok(
    shape.points.some(
      (p) => p.x > outerTangent && p.x < inset && p.y > thickness,
    ),
  );
  assert.ok(
    shape.points.some(
      (p) =>
        p.x > width - inset && p.x < width - outerTangent && p.y > thickness,
    ),
  );
  assert.ok(
    shape.points.some(
      (p) =>
        p.x > inset &&
        p.x < inset + 66 &&
        Math.abs(p.y - (thickness + height)) < 0.01,
    ),
  );
  assert.ok(
    shape.points.some(
      (p) =>
        p.x > width - inset - endWidth &&
        p.x < width - inset &&
        Math.abs(p.y - (thickness + height)) < 0.01,
    ),
  );
});

test("narrow notification well shares the bottom contour of wider islands", () => {
  const top = 26;
  const islandHeight = 38;
  const islands = [
    { x: 192, y: top, width: 66, height: islandHeight, visible: true },
    { x: 1940, y: top, width: 62, height: islandHeight, visible: true },
    { x: 2050, y: top, width: 210, height: islandHeight, visible: true },
  ];
  const geometry = contour(2560, 1440, 26, 62, 4.5, islands, null, []);
  check(geometry, 2560, 1440);
  for (const island of islands) {
    assert.ok(
      geometry.points.some(
        (point) =>
          point.x > island.x &&
          point.x < island.x + island.width &&
          Math.abs(point.y - (top + islandHeight)) < 0.01,
      ),
      "island has no full-depth bottom at x=" + island.x,
    );
  }
});

test("bar and media controls use shared island height and inset", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const theme = fs.readFileSync(path.join(root, "Theme.qml"), "utf8");
  const bar = fs.readFileSync(path.join(root, "AmbientBar.qml"), "utf8");
  const media = fs.readFileSync(
    path.join(root, "NowPlayingIsland.qml"),
    "utf8",
  );
  const system = fs.readFileSync(path.join(root, "SystemIsland.qml"), "utf8");
  const islandHeight = Number(
    theme.match(/property int barIslandHeight: (\d+)/)?.[1],
  );
  const selectionInset = Number(
    theme.match(/property int barSelectionInset: (\d+)/)?.[1],
  );
  assert.equal(islandHeight, 50);
  assert.ok(selectionInset >= 5);
  assert.ok(2 * selectionInset < islandHeight);
  assert.equal(
    (bar.match(/height: bars\.theme\.barIslandHeight(?!\s*-)/g) || []).length,
    5,
  );
  assert.match(media, /height: theme\.barIslandHeight/);
  assert.match(system, /implicitHeight: theme\.barIslandHeight/);
});

test("unmeasured and nonfinite reactive bounds cannot produce invalid SVG", () => {
  for (const dimensions of [
    [NaN, 1440, 26, 62],
    [2560, Infinity, 26, 62],
    [2560, 1440, NaN, 62],
    [2560, 1440, 26, Infinity],
  ]) {
    assert.equal(contour(...dimensions, 4.5, [], null, []).inner, "");
  }
  const withUnmeasured = contour(
    2560,
    1440,
    26,
    62,
    4.5,
    [
      { x: NaN, y: 26, width: 66, height: 38, visible: true },
      { x: 1940, y: 26, width: 62, height: 38, visible: true },
    ],
    null,
    [{ x: Infinity, y: 120, width: 440, height: 160, visible: true }],
  );
  const stable = contour(
    2560,
    1440,
    26,
    62,
    4.5,
    [{ x: 1940, y: 26, width: 62, height: 38, visible: true }],
    null,
    [],
  );
  assert.equal(withUnmeasured.inner, stable.inner);
  assert.equal(withUnmeasured.fill, stable.fill);
});

test("frame-mode transitions animate the shared contour and island layout", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const bar = fs.readFileSync(path.join(root, "AmbientBar.qml"), "utf8");
  const frame = fs.readFileSync(path.join(root, "DesktopFrame.qml"), "utf8");
  assert.match(bar, /property real frameBlend: bars\.frameVisible \? 1 : 0/);
  assert.match(bar, /Behavior on frameBlend\s*\{\s*NumberAnimation/);
  assert.match(bar, /duration: bar\.motion\.morph/);
  for (const margin of [
    "leftMargin",
    "rightMargin",
    "topMargin",
    "bottomMargin",
  ])
    assert.match(bar, new RegExp(margin + ":[^\\n]*bar\\.frameBlend"));
  assert.match(bar, /onFrameBlendChanged: Qt\.callLater\(publishOrigins\)/);
  assert.match(bar, /onXChanged: Qt\.callLater\(bar\.publishOrigins\)/);
  assert.match(bar, /onYChanged: Qt\.callLater\(bar\.publishOrigins\)/);
  assert.match(frame, /visible: opacity > 0/);
  assert.match(frame, /opacity: output\.exposed \? 1 : 0/);
  assert.match(frame, /Behavior on opacity\s*\{\s*NumberAnimation/);
  assert.match(frame, /duration: frame\.motion\.morph/);
  assert.match(
    fs.readFileSync(path.join(root, "FrameGeometry.js"), "utf8"),
    /squircle\.cornerPoint/,
  );
});

test("bar reserves equal vertical space and frame joins start at measured screen bounds", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const theme = fs.readFileSync(path.join(root, "Theme.qml"), "utf8");
  const bar = fs.readFileSync(path.join(root, "AmbientBar.qml"), "utf8");
  const host = fs.readFileSync(
    path.join(root, "ShellExpansionHost.qml"),
    "utf8",
  );
  const system = fs.readFileSync(path.join(root, "SystemIsland.qml"), "utf8");
  assert.match(theme, /property int barInsetBottom: barInsetTop/);
  assert.match(
    theme,
    /property int barHeight: barIslandHeight \+ barInsetTop \+ barInsetBottom/,
  );
  assert.match(
    theme,
    /property int frameIslandInset: frameThickness \+ radiusIsland \* 2 \+ spacing1/,
  );
  assert.match(
    bar,
    /screenOffset: Math\.max\(0, \(modelData\.width - bar\.width\) \/ 2\)/,
  );
  assert.match(host, /topOffset: frameVisible \? theme\.frameThickness/);
  assert.match(
    system,
    /height: 38\s+anchors\.verticalCenter: parent\.verticalCenter/,
  );
});

test("clock reappears with the closing hub morph rather than a binary timer switch", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const bar = fs.readFileSync(path.join(root, "AmbientBar.qml"), "utf8");
  const host = fs.readFileSync(
    path.join(root, "ShellExpansionHost.qml"),
    "utf8",
  );
  const shell = fs.readFileSync(path.join(root, "shell.qml"), "utf8");
  assert.match(host, /readonly property real clockReveal:/);
  assert.match(
    host,
    /const progress = Math\.min\(widthProgress, heightProgress\)/,
  );
  assert.match(
    bar,
    /visible: bars\.clockReveal > 0\.001\s+opacity: bars\.clockReveal/,
  );
  assert.match(shell, /clockReveal: resizeOverlay\.open/);
});

test("frame pulse is only painted during active reduced-motion loading", () => {
  const qml = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/DesktopFrame.qml",
    ),
    "utf8",
  );
  assert.match(
    qml,
    /OutlinePulse\s*\{[\s\S]*?active: output\.exposed && output\.busyHere && !frame\.motion\.enabled/,
  );
  assert.match(qml, /contourPath: output\.geometry\.inner/);
  assert.doesNotMatch(qml, /stationaryPath/);
});

test("motion-enabled frame loading uses the shared tapered glowing tracer", () => {
  const qml = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/DesktopFrame.qml",
    ),
    "utf8",
  );
  assert.match(qml, /import "OutlineTrace\.js" as OutlineTrace/);
  assert.match(
    qml,
    /Canvas\s*\{[\s\S]*?onPaint: \{[\s\S]*?OutlineTrace\.paint/,
  );
  assert.match(
    qml,
    / {12}Canvas\s*\{[\s\S]*?onPaint: \{[\s\S]*?OutlineTrace\.paint/,
  );
  assert.match(
    qml,
    /visible: output\.exposed && output\.busyHere && frame\.motion\.enabled/,
  );
  assert.match(qml, /OutlinePulse\s*\{/);
});

test("the hub's content reveal follows its surface without leaving visible clipped fragments", () => {
  const qml = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
    ),
    "utf8",
  );
  assert.match(
    qml,
    /property real chromeOpacity: expansionState\.hasCurrent && contentExpanded \? 1 : 0/,
  );
  assert.match(qml, /Behavior on chromeOpacity/);
  assert.match(
    qml,
    /return host\.chromeOpacity \* Math\.max\(0, Math\.min\(1,/,
  );
  for (const id of ["tabs", "hubFooter", "contentViewport"]) {
    assert.match(
      qml,
      new RegExp(`id: ${id}\\s+opacity: shellSurface\\.contentReveal`),
    );
  }
  // WidgetHelp implements its own opacity binding for open/close. The
  // compositing fade belongs to its parent Item, not the help widget itself.
  assert.match(
    qml,
    /Item\s*\{[\s\S]*?opacity: shellSurface\.contentReveal\s+WidgetHelp\s*\{/,
  );
  assert.doesNotMatch(
    qml,
    /id: scopedHelp\s+opacity: shellSurface\.contentReveal/,
  );
  assert.match(qml, /fillColor: host\.theme\.background/);
});

test("all hub visual modes have stable terminal dimensions", () => {
  const source = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
    ),
    "utf8",
  );
  assert.match(source, /compactWidth: barVisible \?/);
  assert.match(source, /compactHeight: barVisible \?/);
  assert.match(
    source,
    /targetWidth: contentExpanded \? Math\.max\(contentWidth, expansionState\.originWidth\) : closing \? closeWidth : barVisible \? Math\.max\(1, expansionState\.originWidth\) : compactWidth/,
  );
  assert.match(
    source,
    /targetHeight: contentExpanded \? Math\.max\(contentHeight, expansionState\.originHeight\) : closing \? closeHeight : barVisible \? Math\.max\(1, expansionState\.originHeight\) : compactHeight/,
  );
  assert.match(source, /host\.closeWidth = Math\.max\(1, host\.compactWidth\)/);
  assert.match(
    source,
    /host\.closeHeight = Math\.max\(1, host\.compactHeight\)/,
  );
  const terminal = (frame, bar, dockWidth, frameRadius) =>
    bar ? dockWidth : frame ? Math.max(64, frameRadius * 2) : 64;
  assert.equal(terminal(false, false, 206, 28), 64);
  assert.equal(terminal(false, true, 206, 28), 206);
  assert.equal(terminal(true, false, 206, 28), 64);
  assert.equal(terminal(true, true, 206, 28), 206);
});

test("moving full-screen loading trace uses a bounded Canvas texture", () => {
  const qml = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/DesktopFrame.qml",
    ),
    "utf8",
  );
  assert.match(qml, /OutlineTrace\.traceBounds\(output\.geometry\.points/);
  assert.match(qml, /width: bounds \? bounds\.width : 1/);
  assert.match(qml, /height: bounds \? bounds\.height : 1/);
  assert.match(qml, /onBoundsChanged: requestPaint\(\)/);
  assert.doesNotMatch(qml, /id: busyTrace\s+anchors\.fill: parent/);
});

test("reduced-motion loading softly pulses the entire outline on both surfaces", () => {
  const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
  const frame = fs.readFileSync(path.join(root, "DesktopFrame.qml"), "utf8");
  const outline = fs.readFileSync(
    path.join(root, "LoadingOutline.qml"),
    "utf8",
  );
  const pulse = fs.readFileSync(path.join(root, "OutlinePulse.qml"), "utf8");
  assert.match(
    frame,
    /OutlinePulse\s*\{[\s\S]*?active: output\.exposed && output\.busyHere && !frame\.motion\.enabled/,
  );
  assert.match(frame, /contourPath: output\.geometry\.inner/);
  assert.match(
    outline,
    /OutlinePulse\s*\{[\s\S]*?active: outline\.active && !outline\.motionEnabled/,
  );
  assert.match(
    outline,
    /contourPath: outline\.surface\.buildPath\(outline\.inset\)/,
  );
  assert.match(pulse, /SequentialAnimation on intensity/);
  assert.match(pulse, /running: pulse\.active/);
  assert.match(pulse, /loops: Animation\.Infinite/);
  assert.equal((pulse.match(/duration: 1800/g) || []).length, 2);
  assert.match(pulse, /opacity: pulse\.intensity/);
  assert.match(pulse, /strokeWidth: pulse\.lineWidth \* 4/);
  assert.match(pulse, /strokeWidth: pulse\.lineWidth\s*\n/);
  assert.match(pulse, /path: pulse\.contourPath/);
  assert.doesNotMatch(pulse, /Canvas|requestPaint/);
  assert.match(outline, /visible: outline\.active && outline\.motionEnabled/);
  assert.match(outline, /running: outline\.active && outline\.motionEnabled/);
});

test("expanded gallery preserves the shallow media island before their joined contour", () => {
  const media = { x: 190, y: 12, width: 410, height: 48, visible: true };
  const gallery = { x: 590, y: 12, width: 790, height: 490, visible: true };
  const frame = contour(1920, 1080, 26, 62, 4.5, [media], gallery, []);
  check(frame, 1920, 1080);
  const outerRight = frame.points.findIndex(
    (point) => point.x >= 1832 && point.y <= 26,
  );
  const topContour = frame.points.slice(0, outerRight);
  assert.ok(
    topContour.some(
      (point) => point.x > 540 && point.x < 570 && Math.abs(point.y - 60) < 1,
    ),
  );
  assert.ok(
    topContour
      .filter((point) => point.x > 200 && point.x < 540)
      .every((point) => point.y <= 62),
    "gallery must not extend deep under the media island",
  );
  assert.ok(
    topContour.some(
      (point) => point.x >= 600 && point.x <= 650 && point.y > 470,
    ),
    "gallery must still retain its full height",
  );
  assert.ok(
    frame.inner.includes("C"),
    "joined corners must retain their continuous cubics",
  );
});

test("attached status islands approach the outer frame corner without clipping the notch", () => {
  const theme = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/Theme.qml"),
    "utf8",
  );
  const bar = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/AmbientBar.qml",
    ),
    "utf8",
  );
  assert.match(
    theme,
    /frameIslandInset: frameThickness \+ radiusIsland \* 2 \+ spacing1/,
  );
  assert.match(
    bar,
    /leftMargin: bars\.theme\.spacing3 \+ \(bar\.frameLocalInset - bars\.theme\.spacing3\) \* bar\.frameBlend/,
  );
  assert.match(
    bar,
    /rightMargin: bars\.theme\.spacing3 \+ \(bar\.frameLocalInset - bars\.theme\.spacing3\) \* bar\.frameBlend/,
  );
  // The first and last islands have room for a curved shoulder without
  // being constrained by the previous full-size panel corner.
  const sideInset = 26 + 22 * 2 + 4;
  assert.ok(
    sideInset < 26 + 62 + 4,
    "move islands outward from the previous layout",
  );
  assert.ok(sideInset > 26 + 22, "retain clearance inside the frame");
  for (const width of [800, 1280, 1920, 3840]) {
    assert.ok(width - 2 * sideInset >= 600);
  }
});

test("connected hub footer limit remains tied to the contour with no mesh-only render points", () => {
  const s = require("node:fs").readFileSync(
    require("node:path").join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/FrameGeometry.js",
    ),
    "utf8",
  );
  assert.match(
    s,
    /function hubBottomLimit\(width, height, thickness, radius\)/,
  );
  assert.match(s, /hubBottomLimit\(width, height, thickness, radius\)/);
  assert.doesNotMatch(s, /renderPoints|native.*paint|GPU render contour/);
});

test("symmetric frame-on status insets approach the maximum safe corner clearance", () => {
  const theme = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/Theme.qml"),
    "utf8",
  );
  const bar = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/AmbientBar.qml",
    ),
    "utf8",
  );
  const inset = 26 + 22 * 2 + 4;
  assert.equal(26 + 62 + 4 - inset, 18, "gain another 18px on both edges");
  assert.equal(
    inset - 26,
    48,
    "bar coordinates exclude compositor frame reservation",
  );
  assert.ok(
    theme.includes(
      "frameIslandInset: frameThickness + radiusIsland * 2 + spacing1",
    ),
  );
  assert.match(
    bar,
    /frameLocalInset: Math\.max\(0, bars\.theme\.frameIslandInset - screenOffset\)/,
  );
  assert.ok(
    bar.includes(
      "leftMargin: bars.theme.spacing3 + (bar.frameLocalInset - bars.theme.spacing3) * bar.frameBlend",
    ),
  );
  assert.ok(
    bar.includes(
      "rightMargin: bars.theme.spacing3 + (bar.frameLocalInset - bars.theme.spacing3) * bar.frameBlend",
    ),
  );
});

test("outward status-island positions retain full curved hover and press contours on every screen width", () => {
  for (const width of [800, 1280, 1920, 3840]) {
    const inset = 26 + 22 * 2 + 4;
    const left = {
      x: inset,
      y: 26,
      width: 155,
      height: 50,
      visible: true,
      hovered: true,
    };
    const right = {
      x: width - inset - 180,
      y: 26,
      width: 180,
      height: 50,
      visible: true,
      pressed: true,
    };
    const result = contour(width, 1080, 26, 62, 4.5, [left, right], null, []);
    check(result, width, 1080);
    assert.match(
      result.hoverFill,
      /^M/,
      "left status hover must use a real curved notch",
    );
    assert.match(
      result.pressedFill,
      /^M/,
      "right status press must use a real curved notch",
    );
    assert.ok(
      result.points.some(
        (point) => Math.abs(point.x - left.x) < 0.02 && point.y >= left.y,
      ),
      "left notch starts at its actual hit area, not a clipped fake corner",
    );
    assert.ok(
      result.points.some(
        (point) =>
          Math.abs(point.x - (right.x + right.width)) < 0.02 &&
          point.y >= right.y,
      ),
      "right notch ends at its actual hit area, without clipping its corner",
    );
  }
});

test("bar reservation is subtracted exactly once from the outer island positions", () => {
  const bar = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/AmbientBar.qml",
    ),
    "utf8",
  );
  assert.match(
    bar,
    /screenOffset: Math\.max\(0, \(modelData\.width - bar\.width\) \/ 2\)/,
  );
  assert.match(
    bar,
    /frameLocalInset: Math\.max\(0, bars\.theme\.frameIslandInset - screenOffset\)/,
  );
  for (const screenOffset of [0, 8, 20, 26, 32]) {
    const frameThickness = 26,
      cornerRadius = 62,
      safety = 4;
    const target = frameThickness + cornerRadius + safety;
    const local = Math.max(0, target - screenOffset);
    assert.equal(
      screenOffset + local,
      target,
      "bar hit regions and shared frame contour must agree in screen coordinates",
    );
    assert.ok(target > frameThickness + cornerRadius + 3);
  }
});

test("outward end islands keep a broad curved shoulder instead of being clipped by the panel corner", () => {
  for (const width of [800, 1280, 1920, 3840]) {
    const inset = 26 + 22 * 2 + 4;
    const result = contour(
      width,
      1080,
      26,
      62,
      4.5,
      [
        {
          x: inset,
          y: 26,
          width: 155,
          height: 50,
          visible: true,
          hovered: true,
        },
        {
          x: width - inset - 180,
          y: 26,
          width: 180,
          height: 50,
          visible: true,
          pressed: true,
        },
      ],
      null,
      [],
    );
    check(result, width, 1080);
    // The top corner and the outer island shoulder each get a real arc,
    // rather than the previous 2.4px tangent at x=92.
    assert.equal(result.points[0].x, 26 + 28);
    assert.ok(
      result.points.some((p) => Math.abs(p.x - inset) < 0.01 && p.y > 40),
    );
    assert.ok(
      result.points.some(
        (p) => Math.abs(p.x - (width - inset)) < 0.01 && p.y > 40,
      ),
    );
    assert.match(result.inner, /C/);
    assert.match(result.hoverFill, /C/);
    assert.match(result.pressedFill, /C/);
  }
});

test("frame outline uses the shell large radius instead of the oversized panel radius", () => {
  const theme = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/Theme.qml"),
    "utf8",
  );
  assert.match(theme, /frameRounding: radiusLarge/);
  assert.match(theme, /radiusLarge: 42/);
  assert.match(theme, /radiusPanel: 62/);
  const frame = contour(2560, 1440, 26, 42, 4.5, [], null, []);
  check(frame, 2560, 1440);
  assert.equal(frame.points[0].x, 26 + 42);
  assert.ok(
    frame.points.some(
      (p) =>
        Math.abs(p.x - 26) < 0.001 && Math.abs(p.y - (1440 - 26 - 42)) < 0.001,
    ),
  );
});

test("outer island shoulders join the monitor corner without a stray top-edge line", () => {
  const width = 2560;
  const inset = 26 + 22 * 2 + 4;
  const frame = contour(
    width,
    1440,
    26,
    42,
    4.5,
    [
      { x: inset, y: 26, width: 155, height: 50, visible: true },
      { x: width - inset - 180, y: 26, width: 180, height: 50, visible: true },
    ],
    null,
    [],
  );
  check(frame, width, 1440);
  const start = frame.points[0];
  const end = frame.points[frame.points.length - 1];
  assert.equal(start.x, 54);
  assert.equal(start.y, 26);
  // An open 34px closing chord rendered as a thin horizontal stroke beside
  // the workspace selector. The contour must close at its exact first point.
  assert.deepEqual({ x: end.x, y: end.y }, { x: start.x, y: start.y });
  // With the near-edge shoulder exactly filling the 20px gap, the first
  // contour command cannot draw the horizontal 4px stub seen previously.
  assert.match(frame.inner, /^M54 26 L54 26 C/);
  assert.match(frame.inner, /C[^M]*L2506 26 C/);
  assert.doesNotMatch(frame.inner, /^M54 26 L58 26 C/);
});

test("island collision suppression holds layout until the hub clears the hysteresis band", () => {
  const island = { x: 100, y: 12, width: 80, height: 46 };
  const hub = { x: 176, y: 20, width: 500, height: 320, visible: true };
  assert.equal(context.islandOccluded(island, hub, false), true);
  assert.equal(
    context.islandOccluded(island, { ...hub, x: 178 }, false),
    false,
  );
  assert.equal(context.islandOccluded(island, { ...hub, x: 184 }, true), true);
  assert.equal(context.islandOccluded(island, { ...hub, x: 190 }, true), false);
  assert.equal(context.islandOccluded(island, { ...hub, y: 80 }, false), false);
  assert.equal(
    context.islandOccluded(island, { ...hub, visible: false }, true),
    false,
  );
  assert.equal(
    context.islandOccluded(island, { ...hub, width: 0 }, true),
    false,
  );
  assert.equal(context.islandOccluded(island, { ...hub, x: NaN }, true), false);
});

test("island occlusion fades through the shared contour while hit regions close immediately", () => {
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  const bar = qml("AmbientBar.qml");
  const media = qml("NowPlayingIsland.qml");
  const shell = qml("shell.qml");
  const host = qml("ShellExpansionHost.qml");

  for (const name of ["workspace", "notification", "recording", "system"]) {
    assert.match(bar, new RegExp("property bool " + name + "Occluded: false"));
    assert.match(bar, new RegExp("bar\\." + name + "Occluded \\? 0 : 1"));
  }
  assert.match(bar, /property bool mediaOccluded: false/);
  assert.match(media, /opacity: media.available && !occluded \? 1 : 0/);
  assert.match(bar, /item.opacity > 0.01/);
  assert.match(bar, /height: item.height \* item.opacity/);
  assert.match(bar, /enabled: !bar.recordingOccluded/);
  assert.match(
    bar,
    /onOpacityChanged: if \(bars.frameVisible\)\s+Qt.callLater\(bar.publishOrigins\)/,
  );
  assert.match(media, /enabled: !occluded/);
  assert.match(media, /duration: island.motion.effectsNormal/);
  assert.match(shell, /hubBounds: expansionHost.frameBounds/);
  assert.match(shell, /hubScreen: expansionHost.screen/);
  assert.match(
    host,
    /enabled: host.expansionState.hasCurrent && host.recordingState.capturing/,
  );
  assert.match(host, /onActivated: host.recordingStopRequested\(\)/);
  assert.doesNotMatch(
    host,
    /recordingStatusInHub|notificationStatusInHub|id: footerStatus/,
  );
});
