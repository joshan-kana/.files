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
    name === "updateBands" ? "values" : "frameTime",
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
        attackMultiplier: 1,
        releaseMultiplier: 1,
        hasEnergy: true,
        smoothingSilence: false,
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
    attackMultiplier: 1,
    releaseMultiplier: 1,
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

test("native bars consume one shared full-resolution target without per-bar QML bindings", () => {
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
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );

  assert.match(bars, /import DesktopShell\.Visuals 1\.0/);
  assert.match(bars, /SpectrumBarsItem\s*\{/);
  assert.match(
    bars,
    /targetBands: root\.rendering \? root\.spectrum\.targetBands : \[\]/,
  );
  assert.match(bars, /edges: root\.bandEdges/);
  assert.match(bars, /decaying: root\.spectrum\.decaying/);
  assert.doesNotMatch(bars, /\bRepeater\s*\{/);
  assert.match(native, /QSGGeometryNode/);
  assert.match(native, /QQuickWindow::frameSwapped/);
  for (const rate of [320, 110, 120, 45, 10])
    assert.match(native, new RegExp("-delta \\* " + rate + "\\b"));
  assert.match(curve, /onNeedsInterpolationChanged: syncInterpolation\(\)/);
  assert.match(curve, /spectrum\.curveSubscribers/);
  assert.match(
    curve,
    /!root\.enabled \|\| !root\.visible \|\| root\.opacity <= 0/,
  );
});

test("bar-only audio updates leave QML interpolation idle while maintaining full targets", () => {
  const update = qmlFunction("updateBands");
  const state = {
    bands: [],
    targetBands: [],
    hasEnergy: false,
    interpolating: false,
    decaying: false,
    smoothingSilence: false,
    curveSubscribers: 0,
  };
  const first = seededBands(96, 11);
  const second = seededBands(96, 13);
  update(state, first);
  assert.equal(state.bands, first);
  assert.equal(state.targetBands, first);
  assert.equal(state.hasEnergy, true);
  update(state, second);
  assert.equal(
    state.bands,
    first,
    "native bar frames must not invalidate QML bands",
  );
  assert.equal(state.targetBands, second);
  assert.equal(state.interpolating, false);
  update(state, Array(96).fill(0));
  assert.equal(
    state.bands,
    second,
    "silent release begins from the latest audio data",
  );
  assert.equal(state.smoothingSilence, true);
  assert.equal(state.interpolating, true);
});

test("visualizer attack and release are independently adjustable without changing the decay tail", () => {
  const advance = qmlFunction("advanceBands");
  const measure = (
    from,
    to,
    attackMultiplier,
    releaseMultiplier,
    decaying = false,
  ) => {
    const state = {
      bands: Array(96).fill(from),
      targetBands: Array(96).fill(to),
      frameA: [],
      frameB: [],
      decaying,
      interpolating: true,
      lowHz: 20,
      highHz: 20000,
      attackMultiplier,
      releaseMultiplier,
      hasEnergy: true,
      smoothingSilence: false,
    };
    advance(state, 1 / 120);
    return state.bands[50];
  };
  assert.ok(measure(0, 1, 2, 1) > measure(0, 1, 0.5, 1));
  assert.ok(measure(1, 0, 1, 2) < measure(1, 0, 1, 0.5));
  assert.equal(measure(1, 0, 2, 2, true), measure(1, 0, 0.5, 0.5, true));
});

test("spectrum tuning is persistent, resettable, and independent of reactive tint", () => {
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  const preferences = qml("AppearancePreferences.qml");
  const detail = qml("SettingsDetail.qml");
  const shell = qml("shell.qml");
  const reactive = qml("MusicReactiveState.qml");
  for (const name of [
    "spectrumSensitivity",
    "spectrumAttack",
    "spectrumRelease",
  ]) {
    assert.ok(preferences.includes(`effective("${name}")`));
    assert.ok(preferences.includes(`key: "${name}"`));
    assert.match(preferences, /saved\.resetMany\(spectrumParameters\.map/);
    assert.match(detail, /return appearance\.spectrumParameters/);
    assert.ok(shell.includes(`qmlAppearance.${name}`));
    assert.ok(!reactive.includes(name));
  }
  for (const property of [
    "sensitivity",
    "attackMultiplier",
    "releaseMultiplier",
  ])
    assert.ok(
      qml("SpectrumBars.qml").includes(
        `${property}: root.spectrum.${property}`,
      ),
    );
  assert.match(qml("SpectrumCurve.qml"), /raw \* spectrum.sensitivity/);
});

test("adding or removing another curve preserves the existing interpolation frame", () => {
  const handler = source
    .split("onCurveSubscribersChanged: {")[1]
    .split("\n    }")[0];
  const change = new Function("state", "with (state) {" + handler + "}");
  const original = [0.2, 0.4];
  const state = {
    bands: original,
    targetBands: [0.9, 0.8],
    curveSubscribers: 2,
    hadCurveSubscribers: true,
    active: true,
    decaying: false,
    smoothingSilence: false,
    interpolating: true,
  };
  change(state);
  assert.equal(state.bands, original);
  state.curveSubscribers = 1;
  change(state);
  assert.equal(state.bands, original);
  state.curveSubscribers = 0;
  change(state);
  assert.equal(state.hadCurveSubscribers, false);
  state.curveSubscribers = 1;
  change(state);
  assert.equal(state.bands, state.targetBands);
});

test("spectrum mode changes remain local and legacy wallpaper tuning migrates once", () => {
  const qml = (name) =>
    fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
      "utf8",
    );
  const appearance = qml("AppearancePreferences.qml");
  const body = (name) =>
    appearance.match(
      new RegExp(
        "function " + name + "\\([^\\n]*\\): \\w+ \\{([\\s\\S]*?)\\n    \\}",
      ),
    )[1];
  const migrate = new Function(
    "saved",
    "values",
    body("migrateSpectrumOverrides"),
  );
  const valid = (key, value) =>
    typeof value === "number" &&
    Number.isFinite(value) &&
    (key === "spectrumDensity"
      ? value >= 0.375 && value <= 1.5
      : value >= 0.25 && value <= 1.25);
  const old = {
    wallpaperSpectrumBars: 32,
    wallpaperSpectrumOpacity: 0.4,
    mediaVisualizerMode: "curve",
  };
  assert.deepEqual(migrate({ valid }, old), {
    spectrumDensity: 0.5,
    spectrumOpacity: 0.5,
    mediaVisualizerMode: "curve",
  });
  assert.deepEqual(
    migrate({ valid }, { ...old, spectrumDensity: 1.25, spectrumOpacity: 1 }),
    { spectrumDensity: 1.25, spectrumOpacity: 1, mediaVisualizerMode: "curve" },
  );
  assert.deepEqual(
    migrate(
      { valid },
      { wallpaperSpectrumBars: -1, wallpaperSpectrumOpacity: 8 },
    ),
    {},
  );
  assert.equal(old.wallpaperSpectrumBars, 32);
  assert.deepEqual(migrate({ valid }, {}), {});
  const surfaces = ["wallpaper", "island", "controls", "media", "preview"].map(
    (name) => ({ key: name + "VisualizerMode" }),
  );
  const toggle = new Function(
    "spectrumSurfaces",
    "runtime",
    "spectrumMode",
    "storeOverride",
    "key",
    body("toggleSpectrumMode"),
  );
  const runtime = {
    constraints: {
      appearance: Object.fromEntries(
        surfaces.map(({ key }) => [key, { values: ["bars", "curve"] }]),
      ),
    },
  };
  for (let combination = 0; combination < 2 ** surfaces.length; combination++) {
    const state = Object.fromEntries(
      surfaces.map(({ key }, index) => [
        key,
        combination & (1 << index) ? "curve" : "bars",
      ]),
    );
    for (const { key } of surfaces) {
      const before = { ...state };
      toggle(
        surfaces,
        runtime,
        (key) => state[key],
        (key, value) => (state[key] = value),
        key,
      );
      assert.equal(state[key], before[key] === "bars" ? "curve" : "bars");
      for (const other of surfaces.filter((surface) => surface.key !== key))
        assert.equal(state[other.key], before[other.key]);
    }
  }
  const wrapper = qml("SpectrumVisualizer.qml");
  for (const [name, key] of [
    ["WallpaperSpectrum.qml", "wallpaperVisualizerMode"],
    ["NowPlayingIsland.qml", "islandVisualizerMode"],
    ["ControlsMediaCard.qml", "controlsVisualizerMode"],
    ["MediaContent.qml", "mediaVisualizerMode"],
    ["SettingsDetail.qml", "previewVisualizerMode"],
  ]) {
    assert.match(qml(name), /SpectrumVisualizer \{/);
    assert.ok(qml(name).includes('surfaceKey: "' + key + '"'));
  }
  assert.match(wrapper, /baseDensity \* spectrum\.appearance\.spectrumDensity/);
  assert.match(
    wrapper,
    /baseOpacity \* root\.spectrum\.appearance\.spectrumOpacity/,
  );
});

test("visible spectrum renderers register demand exactly once and release it", () => {
  const wrapper = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/SpectrumVisualizer.qml",
    ),
    "utf8",
  );
  const body = wrapper
    .split("function syncDemand(): void {")[1]
    .split("\n    }")[0];
  const sync = new Function("state", "with (state) {" + body + "}");
  const state = {
    spectrum: { visualizerSubscribers: 0 },
    engaged: true,
    drivesDemand: true,
    demandRegistered: false,
  };
  sync(state);
  sync(state);
  assert.equal(state.spectrum.visualizerSubscribers, 1);
  state.engaged = false;
  sync(state);
  sync(state);
  assert.equal(state.spectrum.visualizerSubscribers, 0);
  state.engaged = true;
  state.drivesDemand = false;
  sync(state);
  assert.equal(state.spectrum.visualizerSubscribers, 0);
});
