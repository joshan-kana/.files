const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const root = path.resolve(__dirname, "../modules/desktop/hyprland/shell");
const script = path.join(root, "scripts/vhs.sh");
const prefs = fs.readFileSync(
  path.join(root, "qml/AppearancePreferences.qml"),
  "utf8",
);
const defaultsNix = fs.readFileSync(path.join(root, "default.nix"), "utf8");
const names = ["crt", "hologram", "glitch", "film", "monochrome", "vhs"];
const keys = [
  "intensity",
  "shape",
  "color",
  "texture",
  "lines",
  "speed",
  "artifacts",
];
const vkeys = [
  "vhsIntensity",
  "vhsTracking",
  "vhsChroma",
  "vhsNoise",
  "vhsScanlines",
  "vhsSpeed",
  "vhsDropouts",
];
const defaultValues = (list) =>
  Object.fromEntries(
    list.map((key) => [key, key.toLowerCase().endsWith("speed") ? 1 : 0.5]),
  );
const bounds = (list) =>
  Object.fromEntries(
    list.map((key) => [
      key,
      {
        min: key.toLowerCase().endsWith("speed") ? 0.25 : 0,
        max: key.toLowerCase().endsWith("speed") ? 2.5 : 1,
      },
    ]),
  );
const payload = (active, tuning = {}) => ({
  enabled: Object.fromEntries(
    names.map((name) => [name, active.includes(name)]),
  ),
  tuning,
});

function compositor(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "screen-compositor-"));
  try {
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin);
    fs.writeFileSync(
      path.join(bin, "glslangValidator"),
      '#!/bin/sh\n[ "${MOCK_BAD_SHADER:-0}" = 0 ]\n',
      { mode: 0o755 },
    );
    fs.writeFileSync(
      path.join(bin, "hyprctl"),
      [
        "#!/bin/sh",
        'if [ "$1" = getoption ]; then',
        '  damage=$(sed -n "1p" "$XDG_RUNTIME_DIR/mock"); vfr=$(sed -n "2p" "$XDG_RUNTIME_DIR/mock"); shader=$(sed -n "3p" "$XDG_RUNTIME_DIR/mock")',
        '  case "$2" in',
        '    debug:damage_tracking) printf "int: %s\\n" "$damage" ;;',
        '    debug:vfr) printf "bool: %s\\n" "$vfr" ;;',
        '    decoration:screen_shader) printf "str: %s\\n" "$shader" ;;',
        "    *) exit 1 ;;",
        "  esac",
        'elif [ "$1" = eval ]; then',
        '  [ "${MOCK_REJECT_CONFIG:-0}" = 0 ] || { echo error; exit 0; }',
        '  damage=$(printf "%s" "$2" | sed -n "s/.*damage_tracking = \\([0-9]\\).*/\\1/p")',
        '  vfr=$(printf "%s" "$2" | sed -En "s/.*vfr = (true|false).*/\\1/p")',
        '  shader=$(printf "%s" "$2" | sed -n \'s/.*screen_shader = "\\([^"]*\\)".*/\\1/p\')',
        '  [ -n "$damage" ] || damage=$(sed -n "1p" "$XDG_RUNTIME_DIR/mock")',
        '  [ -n "$vfr" ] || vfr=$(sed -n "2p" "$XDG_RUNTIME_DIR/mock")',
        '  printf "%s\\n%s\\n%s\\n" "$damage" "$vfr" "$shader" > "$XDG_RUNTIME_DIR/mock"',
        "  echo ok",
        "else exit 1; fi",
      ].join("\n") + "\n",
      { mode: 0o755 },
    );
    fs.writeFileSync(path.join(dir, "mock"), "2\ntrue\n/external.frag\n");
    const env = {
      ...process.env,
      PATH: bin + ":" + process.env.PATH,
      XDG_RUNTIME_DIR: dir,
      HYPRLAND_INSTANCE_SIGNATURE: "test-session",
      SCREEN_COMPOSITOR_GENERATOR: path.join(
        root,
        "scripts/compose-screen-effects.py",
      ),
      DESKTOP_VHS_DEFAULTS: JSON.stringify(defaultValues(vkeys)),
      DESKTOP_VHS_CONSTRAINTS: JSON.stringify(bounds(vkeys)),
      SCREEN_EFFECT_DEFAULTS: JSON.stringify(
        Object.fromEntries(
          names.filter((k) => k !== "vhs").map((k) => [k, defaultValues(keys)]),
        ),
      ),
      SCREEN_EFFECT_CONSTRAINTS: JSON.stringify(bounds(keys)),
      ...Object.fromEntries(
        names.map((k) => [
          "SCREEN_" + k.toUpperCase() + "_SOURCE",
          path.join(root, "shaders/" + k + ".frag"),
        ]),
      ),
    };
    const run = (command, value, extra = {}) =>
      spawnSync(
        "bash",
        [
          script,
          command,
          ...(value === undefined ? [] : [JSON.stringify(value)]),
        ],
        { env: { ...env, ...extra }, encoding: "utf8" },
      );
    const state = () =>
      fs.readFileSync(path.join(dir, "mock"), "utf8").trimEnd().split("\n");
    fn({ dir, run, state });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test("independent effect settings no longer have a single mode enum", () => {
  assert.match(defaultsNix, /screenEffectsEnabled = lib\.mkOption/);
  assert.doesNotMatch(defaultsNix, /screenEffectMode = lib\.mkOption/);
  assert.match(prefs, /storeOverride\("screenEffectsEnabled", enabled\)/);
  assert.doesNotMatch(prefs, /storeOverride\("vhsEnabled"/);
  assert.doesNotMatch(prefs, /storeOverride\("screenEffectMode"/);
  assert.match(prefs, /function resetVhs\(\): void \{\s*applyVhsPreset/);
});

test("composes multiple independent effects and restores original compositor settings", () => {
  compositor(({ dir, run, state }) => {
    assert.equal(run("apply", payload(["crt", "film", "vhs"])).status, 0);
    const shader = state()[2];
    assert.match(shader, /screen-compositions-test-session/);
    const code = fs.readFileSync(shader, "utf8");
    for (const name of ["crt", "film", "vhs"])
      assert.match(
        code,
        new RegExp("stage_" + name + "\\(v_texcoord, colour\\)"),
      );
    assert.doesNotMatch(code, /stage_hologram\(v_texcoord, colour\)/);
    assert.deepEqual(state().slice(0, 2), ["0", "false"]);
    assert.equal(run("apply", payload(["film", "monochrome"])).status, 0);
    assert.notEqual(state()[2], shader);
    assert.equal(run("off").status, 0);
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.ok(
      !fs.existsSync(path.join(dir, "desktop-shell/vhs-state-test-session")),
    );
  });
});

test("static effects and zero-intensity effects preserve redraw policy", () => {
  compositor(({ run, state }) => {
    assert.equal(run("apply", payload(["monochrome"])).status, 0);
    assert.deepEqual(state().slice(0, 2), ["2", "true"]);
    assert.equal(
      run("apply", payload(["crt"], { crt: { intensity: 0 } })).status,
      0,
    );
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.equal(
      run("apply", payload(["film", "crt"], { crt: { intensity: 0 } })).status,
      0,
    );
    assert.doesNotMatch(
      fs.readFileSync(state()[2], "utf8"),
      /stage_crt\(v_texcoord, colour\)/,
    );
  });
});

test("emergency shutdown suspends automatic reapplication until explicit resume", () => {
  compositor(({ dir, run, state }) => {
    assert.equal(run("apply", payload(["crt", "film"])).status, 0);
    assert.equal(run("emergency-off").status, 0);
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    const marker = path.join(
      dir,
      "desktop-shell/screen-effects-paused-test-session",
    );
    assert.ok(fs.existsSync(marker));
    assert.equal(run("apply", payload(["vhs"])).status, 0);
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.equal(
      run("apply", { ...payload(["vhs", "film"]), resume: true }).status,
      0,
    );
    assert.ok(!fs.existsSync(marker));
    assert.match(state()[2], /screen-compositions-test-session/);
  });
});

test("failed compilation, invalid payload and rejected compositor writes preserve state", () => {
  compositor(({ run, state }) => {
    assert.equal(
      run("apply", payload(["crt"], { crt: { intensity: 5 } })).status,
      2,
    );
    assert.equal(
      run("apply", { enabled: { crt: true }, tuning: {} }).status,
      2,
    );
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.equal(
      run("apply", payload(["crt"]), { MOCK_BAD_SHADER: "1" }).status,
      1,
    );
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.equal(
      run("apply", payload(["crt"]), { MOCK_REJECT_CONFIG: "1" }).status,
      1,
    );
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
  });
});

test("emergency shortcut uses suspension, not a regular off toggle", () => {
  const shortcuts = fs.readFileSync(
    path.join(root, "../keybindings.nix"),
    "utf8",
  );
  assert.match(shortcuts, /desktop-shell-vhs emergency-off/);
  assert.match(fs.readFileSync(script, "utf8"), /flock -x 9/);
  assert.match(prefs, /screenEffectsSuspended/);
});

test("VHS preserves independent tracking, grain, scanline and dropout controls", () => {
  const shader = fs.readFileSync(path.join(root, "shaders/vhs.frag"), "utf8");
  for (const key of ["TRACKING", "CHROMA", "NOISE", "SCANLINES", "SPEED"])
    assert.match(shader, new RegExp("const float VHS_" + key + " = 1\\.00;"));
  assert.match(shader, /const float VHS_DROPOUTS = 0\.00;/);
  assert.match(shader, /tapeTime \* 24\.0/);
  assert.match(shader, /tearCenter = mod\(tapeTime/);
  assert.match(
    shader,
    /trackingFlash = .*max\(0\.0, tearDirection\) \* VHS_TRACKING/,
  );
  assert.match(shader, /colour \*= 1\.0 - dropout \* strength \* VHS_DROPOUTS/);
  assert.doesNotMatch(shader, /dropout \* strength \* VHS_NOISE/);
  assert.doesNotMatch(shader, /pointer_position/);
});

test("VHS keyboard and pointer editors retain their independent hit targets", () => {
  const controls = fs.readFileSync(
    path.join(root, "qml/SystemContent.qml"),
    "utf8",
  );
  const panel = fs.readFileSync(path.join(root, "qml/VhsPanel.qml"), "utf8");
  const tile = fs.readFileSync(
    path.join(root, "qml/QuickSettingChip.qml"),
    "utf8",
  );
  const keymap = fs.readFileSync(path.join(root, "keybindings.nix"), "utf8");
  assert.match(controls, /onActivated: root\.appearance\.toggleVhs\(\)/);
  assert.match(controls, /onDetailsRequested: root\.openVhs\(\)/);
  assert.match(controls, /detailActionId: "SystemContent\.vhsTune"/);
  assert.match(
    controls,
    /vhsPanel\.invoke\("handleKey", event\.key, event\.modifiers, event\.isAutoRepeat\)/,
  );
  assert.match(
    tile,
    /TileQuickAction \{[\s\S]*?onActivated: chip\.activated\(\)/,
  );
  assert.match(panel, /onValueRequested: next => panel\.setParameter/);
  assert.match(panel, /shellMatchesHint\("VhsPanel\.toggle", key, modifiers\)/);
  assert.match(keymap, /"SystemContent\.vhsTune" = "SHIFT\+P"/);
  assert.match(keymap, /"VhsPanel\.adjust" = "NAV_HORIZONTAL"/);
  assert.match(prefs, /function setVhsParameter\(key: string, value: real\)/);
  assert.doesNotMatch(prefs, /storeOverride\("vhsEnabled", true\)/);
});

test("VHS tuning survives composition with other effects without parameter leakage", () => {
  compositor(({ run, state }) => {
    const data = payload(["vhs", "crt"], {
      vhs: { vhsIntensity: 0.85, vhsNoise: 0.6, vhsDropouts: 0 },
      crt: { intensity: 0.3, speed: 1.4 },
    });
    assert.equal(run("apply", data).status, 0);
    const content = fs.readFileSync(state()[2], "utf8");
    assert.match(content, /const float VHS_VHS_INTENSITY = 0\.85;/);
    assert.match(content, /const float VHS_VHS_NOISE = 0\.60;/);
    assert.match(content, /const float VHS_VHS_DROPOUTS = 0\.00;/);
    assert.match(content, /const float CRT_FX_INTENSITY = 0\.30;/);
    assert.match(content, /const float CRT_FX_SPEED = 1\.40;/);
    assert.match(content, /stage_crt\(v_texcoord, colour\)/);
    assert.match(content, /stage_vhs\(v_texcoord, colour\)/);
    assert.equal(run("apply", payload(["vhs"], data.tuning)).status, 0);
    assert.doesNotMatch(
      fs.readFileSync(state()[2], "utf8"),
      /stage_crt\(v_texcoord, colour\)/,
    );
    assert.equal(run("off").status, 0);
  });
});

test("unowned external shaders are not removed without a recovery record", () => {
  compositor(({ dir, run, state }) => {
    assert.equal(run("off").status, 0);
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.ok(
      !fs.existsSync(path.join(dir, "desktop-shell/vhs-state-test-session")),
    );
  });
});

test("a corrupted recovery record cannot silently destroy the previous shader", () => {
  compositor(({ dir, run, state }) => {
    assert.equal(run("apply", payload(["crt"])).status, 0);
    const previous = state();
    const recovery = path.join(dir, "desktop-shell/vhs-state-test-session");
    fs.writeFileSync(recovery, "invalid\n");
    assert.notEqual(run("off").status, 0);
    assert.ok(fs.existsSync(recovery));
    assert.deepEqual(state(), previous);
    fs.writeFileSync(recovery, "2\ntrue\n/external.frag\n");
    assert.equal(run("off").status, 0);
    assert.deepEqual(state(), ["2", "true", "/external.frag"]);
    assert.ok(!fs.existsSync(recovery));
  });
});
