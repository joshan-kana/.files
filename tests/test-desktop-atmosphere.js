const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const appearance = read("qml/AppearancePreferences.qml");
const modes = [
  "aurora",
  "liquid",
  "nebula",
  "ripples",
  "geometry",
  "flow",
  "prism",
];

function method(source, signature) {
  const body = source.split(signature + " {")[1].split("\n    }")[0];
  return new Function("ctx", "mode", "with(ctx) {" + body + "}");
}

test("atmosphere mode changes preserve independent audio and spectrum preferences", () => {
  const choose = method(
    appearance,
    "function setAtmospherePresentation(mode: string): void",
  );
  const persistent = {
    atmosphereEnabled: false,
    atmosphereMode: "aurora",
    atmosphereAudioEnabled: false,
    wallpaperSpectrumEnabled: true,
  };
  const ctx = {
    runtime: {
      constraints: { appearance: { atmosphereMode: { values: modes } } },
    },
    sceneValues: {},
    saved: { setMany: (values) => Object.assign(persistent, values) },
    storeOverride: (key, value) => {
      persistent[key] = value;
    },
  };
  for (const mode of modes) {
    choose(ctx, mode);
    assert.equal(persistent.atmosphereEnabled, true);
    assert.equal(persistent.atmosphereMode, mode);
    assert.equal(persistent.atmosphereAudioEnabled, false);
    assert.equal(persistent.wallpaperSpectrumEnabled, true);
  }
  choose(ctx, "off");
  assert.equal(persistent.atmosphereEnabled, false);
  assert.equal(persistent.atmosphereMode, "prism");
  choose(ctx, "invalid");
  assert.equal(persistent.atmosphereEnabled, false);
  ctx.sceneValues = { atmosphereEnabled: true, atmosphereMode: "liquid" };
  choose(ctx, "nebula");
  assert.equal(ctx.sceneValues.atmosphereMode, "nebula");
  assert.equal(persistent.atmosphereMode, "prism");
});

test("only visible animated audio-synchronised effects subscribe, idempotently", () => {
  const effect = read("qml/AtmosphereEffect.qml");
  const sync = method(effect, "function syncDemand(): void");
  const state = {
    reactive: { effectSubscribers: 0 },
    demandRegistered: false,
    animating: true,
    audioSync: true,
  };
  sync(state);
  sync(state);
  assert.equal(state.reactive.effectSubscribers, 1);
  state.audioSync = false;
  sync(state);
  sync(state);
  assert.equal(state.reactive.effectSubscribers, 0);
  state.audioSync = true;
  state.animating = false;
  sync(state);
  assert.equal(state.reactive.effectSubscribers, 0);
  state.animating = true;
  sync(state);
  assert.equal(state.reactive.effectSubscribers, 1);
  state.animating = false;
  sync(state);
  assert.equal(state.reactive.effectSubscribers, 0);
  assert.match(effect, /animating: enabled && visible && motion.enabled/);
  assert.match(effect, /running: effect.animating/);
  assert.match(effect, /Component.onDestruction:[\s\S]*effectSubscribers--/);
  const wallpaper = read("qml/WallpaperSpectrum.qml");
  assert.match(
    wallpaper,
    /!locked && \(appearance.atmosphereEnabled \|\| enabled\)/,
  );
  assert.match(wallpaper, /lastIpcObject.fullscreen > 1/);
  assert.match(wallpaper, /WlrLayer.Bottom/);
  assert.match(
    wallpaper,
    /LazyLoader \{[\s\S]*atmosphereActive: true[\s\S]*LazyLoader \{[\s\S]*atmosphereActive: false/,
  );
  assert.match(wallpaper, /required property bool atmosphereActive/);
  assert.match(
    wallpaper,
    /color: atmosphereActive && visuals.appearance.atmosphereBackdrop/,
  );
  assert.ok(
    wallpaper.indexOf("sourceComponent: AtmosphereEffect") <
      wallpaper.indexOf("SpectrumVisualizer {"),
  );
  assert.match(
    wallpaper,
    /implicitWidth: atmosphereActive && screen \? screen.width : spectrumWidth/,
  );
  assert.match(wallpaper, /WlrKeyboardFocus.None/);
  assert.match(wallpaper, /width: 0[\s\S]*height: 0/);
  assert.match(
    read("qml/shell.qml"),
    /active: visualizerSubscribers > 0[^\n]+atmosphereReactive.effectSubscribers > 0/,
  );
});

test("wallpaper owns all seven atmospheres while fullscreen effects stay in Visual Modes", () => {
  const nix = read("default.nix");
  const declared = nix.split("atmosphereMode.values = [")[1].split("];")[0];
  assert.deepEqual(
    [...declared.matchAll(/"([^"]+)"/g)].map((m) => m[1]),
    modes,
  );
  const controls = read("qml/SystemContent.qml");
  const wallpaper = read("qml/WallpaperPanel.qml");
  const detail = read("qml/WallpaperAtmosphere.qml");
  const shader = read("shaders/atmosphere.frag");
  const visual = controls
    .split("id: visualTiles")[1]
    .split("id: mediaMatrix")[0];
  for (const [index, mode] of modes.entries()) {
    assert.ok(shader.includes("u.style == " + index));
    assert.doesNotMatch(
      visual,
      new RegExp(
        'on(?:Activated|DetailsRequested): root\\.appearance\\.toggleAtmosphere\\("' +
          mode +
          '"',
      ),
    );
    assert.doesNotMatch(
      visual,
      new RegExp('openSetting\\("atmosphere\\.' + mode + '"'),
    );
  }
  const screenModes = vm.runInNewContext(
    read("qml/ScreenEffects.js") + "\n({modes})",
  ).modes;
  assert.deepEqual(Array.from(screenModes), [
    "crt",
    "hologram",
    "glitch",
    "film",
    "monochrome",
  ]);
  for (const mode of screenModes)
    assert.ok(visual.includes('mode: "' + mode + '"'), mode);
  assert.match(
    read("qml/SettingsDetail.qml"),
    /appearance\.setScreenEffect\(screenKind\)/,
  );
  assert.match(nix, /qsb --glsl/);
  assert.match(shader, /effect.rgb, 0.0, 1.0\) \* alpha, alpha/);
  assert.match(wallpaper, /property string view: "gallery"/);
  assert.match(wallpaper, /view === "atmosphere"/);
  assert.match(wallpaper, /WallpaperAtmosphere \{/);
  assert.match(wallpaper, /handlePolicyKey[\s\S]*?atmosphereLayout.handleKey/);
  assert.match(detail, /model: panel.modes/);
  assert.match(detail, /AtmosphereEffect \{/);
  assert.match(detail, /appearance.selectAtmosphere\(modelData\)/);
  assert.match(detail, /appearance.toggleAtmosphere\(panel.mode\)/);
  assert.match(detail, /appearance.setAtmosphereParameter/);
  assert.match(read("keybindings.nix"), /"WallpaperPanel.atmosphere" = "A"/);
  assert.match(read("keybindings.nix"), /"WallpaperAtmosphere.audio" = "B"/);
  assert.match(read("keybindings.nix"), /"WallpaperAtmosphere.backdrop" = "G"/);
});

test("fullscreen effects stay accessible without consuming dashboard letter slots", () => {
  const controls = read("qml/SystemContent.qml");
  const tile = read("qml/ScreenEffectTile.qml");
  const chip = read("qml/QuickSettingChip.qml");
  const detail = read("qml/SettingsDetail.qml");
  const visual = controls
    .split("id: visualTiles")[1]
    .split("id: mediaMatrix")[0];
  for (const mode of ["crt", "hologram", "glitch", "film", "monochrome"]) {
    assert.ok(visual.includes('mode: "' + mode + '"'), mode);
    assert.ok(
      !read("keybindings.nix").includes('"SystemContent.' + mode + 'Toggle"'),
    );
    assert.ok(
      !read("keybindings.nix").includes('"SystemContent.' + mode + 'Details"'),
    );
  }
  assert.match(tile, /detailActionId: "SystemContent\." \+ mode \+ "Details"/);
  assert.doesNotMatch(tile, /actionId:/);
  assert.match(
    visual,
    /onDetailsRequested: root\.openSetting\("screen\." \+ mode\)/,
  );
  assert.match(
    chip,
    /onActivated: chip\.hasDetails \? chip\.detailsRequested\(\) : chip\.activated\(\)/,
  );
  assert.match(
    chip,
    /keyboardFocusable: chip\.hasDetails && chip\.detailShortcut\.length === 0/,
  );
  assert.match(
    read("qml/StateLayer.qml"),
    /activeFocusOnTab: keyboardFocusable && !disabled/,
  );
  assert.match(
    detail,
    /if \(screenTuning\) \{\s*appearance\.setScreenEffect\(screenKind\)/,
  );
  assert.match(read("keybindings.nix"), /"SettingsDetail.toggle" = "T"/);
});

test("screen detail routing is guarded and wallpaper atmosphere uses its own view", () => {
  const controls = read("qml/SystemContent.qml");
  const guard = controls
    .split("function openSetting(name: string): void {")[1]
    .split("helpOpen = false;")[0];
  assert.match(guard, /name.startsWith\("screen\."\)/);
  assert.match(guard, /appearance.screenEffectKinds.includes/);
  assert.doesNotMatch(guard, /name.startsWith\("atmosphere\."\)/);
  assert.match(controls, /wallpaperPanel.invoke\("showGallery"\)/);
  assert.match(controls, /reactive: root.reactive/);
  assert.match(read("qml/WallpaperPanel.qml"), /view = "gallery"/);
});

test("effect tuning persists sparse per-mode overrides instead of copying every default", () => {
  const extract = (signature, args) => {
    const body = appearance.split(signature + " {")[1].split("\n    }")[0];
    return new Function("ctx", ...args, "with(ctx) {" + body + "}");
  };
  const defaults = {
    atmosphereTuning: Object.fromEntries(
      modes.map((mode) => [mode, { opacity: 0.65, speed: 1 }]),
    ),
    screenEffectTuning: Object.fromEntries(
      ["crt", "hologram"].map((mode) => [
        mode,
        { intensity: 0.6, shape: 0.5, speed: 1 },
      ]),
    ),
  };
  const writes = {};
  const state = {
    runtime: {
      appearanceDefaults: defaults,
      constraints: {
        appearance: {
          atmosphereMode: { values: modes },
          atmosphereOpacity: { min: 0.15, max: 1 },
          atmosphereSpeed: { min: 0.25, max: 2 },
          screenEffectsEnabled: { keys: ["vhs", "crt", "hologram"] },
          screenEffectTuning: { intensity: { min: 0, max: 1 } },
        },
      },
    },
    atmosphereTuning: defaults.atmosphereTuning,
    screenEffectTuning: defaults.screenEffectTuning,
    screenEffectKinds: ["vhs", "crt", "hologram"],
    screenEffectEnabled: (mode) => mode === "crt",
    hasOverride: (key) => Object.hasOwn(writes, key),
    storeOverride: (key, value) => {
      writes[key] = value;
      state[key] = value;
    },
    clearOverride: (key) => {
      delete writes[key];
      state[key] = defaults[key];
    },
    vhsApply: { restart: () => {} },
  };
  const setAtmosphere = extract(
    "function setAtmosphereParameter(mode: string, parameter: string, value: var): void",
    ["mode", "parameter", "value"],
  );
  const setScreen = extract(
    "function setScreenEffectValue(mode: string, key: string, value: real): void",
    ["mode", "key", "value"],
  );
  const resetScreenParameter = extract(
    "function resetScreenEffectParameter(mode: string, key: string): void",
    ["mode", "key"],
  );
  const resetScreen = extract(
    "function resetScreenEffect(mode: string): void",
    ["mode"],
  );
  setAtmosphere(state, "aurora", "opacity", 0.7);
  assert.deepEqual(Object.keys(writes.atmosphereTuning), ["aurora"]);
  assert.deepEqual(writes.atmosphereTuning.aurora, { opacity: 0.7 });
  setAtmosphere(state, "aurora", "audio", false);
  setAtmosphere(state, "aurora", "backdrop", true);
  assert.deepEqual(writes.atmosphereTuning.aurora, { opacity: 0.7 });
  setScreen(state, "crt", "intensity", 0.7);
  assert.deepEqual(Object.keys(writes.screenEffectTuning), ["crt"]);
  assert.deepEqual(writes.screenEffectTuning.crt, { intensity: 0.7 });
  resetScreenParameter(state, "crt", "intensity");
  assert.equal("screenEffectTuning" in writes, false);
  setScreen(state, "crt", "intensity", 0.65);
  resetScreen(state, "crt");
  assert.equal("screenEffectTuning" in writes, false);
  assert.match(
    appearance,
    /function setVisualParameter[\s\S]*?spectrumParameters.some/,
  );
  assert.doesNotMatch(appearance, /!atmosphereParameters.some/);
});

test("Wallpaper mode selection preserves the enabled state and parameter resets inherit defaults", () => {
  const extract = (signature, args) => {
    const body = appearance.split(signature + " {")[1].split("\n    }")[0];
    return new Function("ctx", ...args, "with(ctx) {" + body + "}");
  };
  const written = {};
  const ctx = {
    runtime: {
      constraints: { appearance: { atmosphereMode: { values: modes } } },
    },
    sceneValues: {},
    hasOverride: (key) => key in written,
    atmosphereTuning: { geometry: { opacity: 0.8 }, prism: { speed: 1.25 } },
    storeOverride: (key, value) => {
      written[key] = value;
      if (key === "atmosphereTuning") ctx.atmosphereTuning = value;
    },
    clearOverride: (key) => delete written[key],
  };
  const select = extract("function selectAtmosphere(mode: string): void", [
    "mode",
  ]);
  select(ctx, "aurora");
  assert.equal(written.atmosphereMode, "aurora");
  assert.equal(written.atmosphereEnabled, undefined);
  select(ctx, "not-an-atmosphere");
  assert.equal(written.atmosphereMode, "aurora");
  written.atmosphereTuning = ctx.atmosphereTuning;
  const resetParameter = extract(
    "function resetAtmosphereParameter(mode: string, parameter: string): void",
    ["mode", "parameter"],
  );
  resetParameter(ctx, "geometry", "opacity");
  assert.deepEqual(written.atmosphereTuning, { prism: { speed: 1.25 } });
  const reset = extract("function resetAtmosphere(mode: string): void", [
    "mode",
  ]);
  reset(ctx, "prism");
  assert.equal("atmosphereTuning" in written, false);
  const panel = read("qml/WallpaperAtmosphere.qml");
  assert.match(panel, /readonly property int columns: 3/);
  assert.match(panel, /shortcut: panel.runtime.shellChoiceHint\(index\)/);
  assert.match(
    panel,
    /runtime.shellChoiceIndex\(key, modifiers, audioDetailsOpen \? 4 : modes.length\)/,
  );
  assert.match(read("qml/SystemContent.qml"), /Back to wallpaper gallery/);
});

test("wallpaper Atmospheres follows the shared detail-header and controls conventions", () => {
  const panel = read("qml/WallpaperAtmosphere.qml");
  const beforeStyleChoices = panel.split("id: modeFlow")[0];
  const hero = beforeStyleChoices.split("DetailHero {")[1].split("\n    }")[0];
  assert.match(
    hero,
    /title: panel.audioDetailsOpen \? "Audio response" : "Atmospheres"/,
  );
  assert.match(hero, /detail: panel.audioDetailsOpen.*panel\.style\.backdrop/);
  assert.match(
    hero,
    /actions: \[[\s\S]*?ShellAction \{[\s\S]*?id: masterAction/,
  );
  assert.match(
    hero,
    /id: masterAction[\s\S]*?compact: true[\s\S]*?iconOnly: true[\s\S]*?switchControl: true/,
  );
  assert.match(
    hero,
    /id: masterAction[\s\S]*?active: panel\.audioDetailsOpen \? panel\.appearance\.atmosphereAudioEnabled : panel\.appearance\.atmosphereEnabled/,
  );
  assert.match(hero, /id: resetButton/);
  assert.match(beforeStyleChoices, /text: "Styles"/);
  assert.doesNotMatch(
    panel,
    /Atmosphere disabled|Atmosphere enabled|Choose an atmosphere without turning it on|Animated GPU backgrounds/,
  );
  assert.doesNotMatch(panel, /width: Math\.max\(panel\.theme\.fontSize\(210\)/);
  assert.match(panel, /text: "Preview"/);
  assert.match(
    panel,
    /id: audioButton[\s\S]*?iconOnly: true[\s\S]*?switchControl: true/,
  );
  assert.match(panel, /text: "Theme background"[\s\S]*?id: backdropButton/);
  assert.match(
    panel,
    /id: backdropButton[\s\S]*?iconOnly: true[\s\S]*?switchControl: true/,
  );
  assert.match(panel, /active: panel\.appearance\.atmosphereBackdrop/);
  assert.match(panel, /joined: false/);
  assert.doesNotMatch(panel, /SystemContent\.legend\.back/);
  assert.doesNotMatch(
    read("qml/SettingsDetail.qml"),
    /atmosphereTuning|AtmosphereDetail|atmosphereKind/,
  );
  assert.doesNotMatch(read("keybindings.nix"), /"AtmosphereDetail\./);
  assert.doesNotMatch(
    read("qml/SettingsDetail.qml"),
    /Fullscreen post-processing\. Switching modes/,
  );
});

test("background and audio sync are global, independent of the chosen atmosphere", () => {
  const extract = (signature, args = []) => {
    const body = appearance.split(signature + " {")[1].split("\n    }")[0];
    return new Function("ctx", ...args, "with(ctx) {" + body + "}");
  };
  const defaults = {
    atmosphereMode: "aurora",
    atmosphereTuning: Object.fromEntries(
      modes.map((mode) => [mode, { opacity: 0.65, speed: 1 }]),
    ),
  };
  const written = {};
  const state = {
    atmosphereMode: "aurora",
    atmosphereAudioEnabled: false,
    atmosphereBackdrop: true,
    atmosphereTuning: {
      aurora: { opacity: 0.7 },
      liquid: { opacity: 0.3, speed: 1.4 },
    },
    runtime: {
      appearanceDefaults: defaults,
      constraints: { appearance: { atmosphereMode: { values: modes } } },
    },
    sceneValues: {},
    hasOverride: (key) =>
      key === "atmosphereTuning" || Object.hasOwn(written, key),
    effective: (key) => written[key],
    storeOverride: (key, value) => {
      written[key] = value;
      state[key] = value;
    },
  };
  const style = extract("function atmosphereStyle(mode: string): var", [
    "mode",
  ]);
  const select = extract("function selectAtmosphere(mode: string): void", [
    "mode",
  ]);
  const toggleAudio = extract("function toggleAtmosphereAudio(): void");
  const toggleBackdrop = extract("function toggleAtmosphereBackdrop(): void");
  assert.deepEqual(
    [
      style(state, "aurora").audio,
      style(state, "aurora").backdrop,
      style(state, "aurora").opacity,
    ],
    [false, true, 0.7],
  );
  select(state, "liquid");
  assert.deepEqual(
    [
      style(state, "liquid").audio,
      style(state, "liquid").backdrop,
      style(state, "liquid").opacity,
    ],
    [false, true, 0.3],
  );
  assert.equal(written.atmosphereBackdrop, undefined);
  assert.equal(written.atmosphereAudioEnabled, undefined);
  toggleBackdrop(state);
  toggleAudio(state);
  assert.equal(written.atmosphereBackdrop, false);
  assert.equal(written.atmosphereAudioEnabled, true);
  assert.deepEqual(state.atmosphereTuning, {
    aurora: { opacity: 0.7 },
    liquid: { opacity: 0.3, speed: 1.4 },
  });
  select(state, "aurora");
  assert.deepEqual(
    [style(state, "aurora").audio, style(state, "aurora").backdrop],
    [true, false],
  );
});

test("legacy per-style presentation switches migrate without clobbering global overrides", () => {
  const extract = (signature, args = []) => {
    const body = appearance.split(signature + " {")[1].split("\n    }")[0];
    return new Function("ctx", ...args, "with(ctx) {" + body + "}");
  };
  const migrate = extract(
    "function migrateAtmosphereOverrides(values: var): var",
    ["values"],
  );
  const ctx = { runtime: { appearanceDefaults: { atmosphereMode: "aurora" } } };
  const legacy = {
    atmosphereMode: "liquid",
    atmosphereTuning: {
      aurora: { audio: true, backdrop: false, opacity: 0.9 },
      liquid: { audio: false, backdrop: true, speed: 1.3 },
      prism: { backdrop: false },
    },
  };
  const next = migrate(ctx, legacy);
  assert.deepEqual(next.atmosphereTuning, {
    aurora: { opacity: 0.9 },
    liquid: { speed: 1.3 },
  });
  assert.equal(next.atmosphereAudioEnabled, false);
  assert.equal(next.atmosphereBackdrop, true);
  assert.equal(next.atmosphereMode, "liquid");
  assert.equal(legacy.atmosphereTuning.liquid.backdrop, true);
  assert.equal(migrate(ctx, next), next, "migration must be idempotent");
  const explicit = migrate(ctx, { ...legacy, atmosphereBackdrop: false });
  assert.equal(
    explicit.atmosphereBackdrop,
    false,
    "global override wins over legacy style",
  );
  const nix = read("default.nix")
    .split("atmosphereTuning = lib.mkOption {")[1]
    .split("atmosphereEnabled = lib.mkOption {")[0];
  assert.doesNotMatch(nix, /\baudio = lib.mkOption|\bbackdrop = lib.mkOption/);
  assert.match(appearance, /saved\.write\(migratedAtmosphere\)/);
});

test("tuning an inactive fullscreen effect never enables that effect or reapplies another one", () => {
  const extract = (signature, args = []) => {
    const body = appearance.split(signature + " {")[1].split("\n    }")[0];
    return new Function("ctx", ...args, "with(ctx) {" + body + "}");
  };
  let applications = 0;
  const ctx = {
    runtime: {
      constraints: {
        appearance: {
          screenEffectsEnabled: { keys: ["vhs", "crt", "hologram"] },
          screenEffectTuning: { intensity: { min: 0, max: 1 } },
        },
      },
    },
    screenEffectTuning: {},
    screenEffectKinds: ["vhs", "crt", "hologram"],
    screenEffectEnabled: (mode) => mode === "crt",
    hasOverride: () => false,
    storeOverride: () => {},
    vhsApply: { restart: () => applications++ },
    setScreenEffect: () => {
      throw new Error("tuning changed the enabled mode");
    },
  };
  const set = extract(
    "function setScreenEffectValue(mode: string, key: string, value: real): void",
    ["mode", "key", "value"],
  );
  set(ctx, "hologram", "intensity", 0.6);
  assert.equal(applications, 0);
  set(ctx, "crt", "intensity", 0.5);
  assert.equal(applications, 1);
});

test("wallpaper audio response has a separate envelope and independent controls", () => {
  const qml = read("qml/shell.qml");
  const panel = read("qml/WallpaperAtmosphere.qml");
  const source = read("qml/AppearancePreferences.qml");
  assert.match(qml, /id: atmosphereReactive/);
  assert.match(qml, /reactive: root.atmosphereReactiveRef/);
  assert.match(
    qml,
    /sensitivity: qmlAppearance.atmosphereReactive.sensitivity/,
  );
  assert.match(
    qml,
    /root.musicReactiveSurfaceVisible \|\| atmosphereReactive.effectSubscribers > 0/,
  );
  assert.match(panel, /audioDetailsOpen/);
  assert.match(panel, /setAtmosphereReactiveParameter/);
  assert.match(panel, /audioDetailsButton/);
  assert.match(source, /atmosphereReactive: Object.assign/);
  assert.doesNotMatch(source, /migrateScreenEffects|migrateEffectOverrides/);
});
