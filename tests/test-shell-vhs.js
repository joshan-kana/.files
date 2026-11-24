const test = require("node:test");
const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const root = path.join(__dirname, "..");
const shell = path.join(root, "modules/desktop/hyprland/shell");
const shader = path.join(shell, "shaders/vhs.frag");
const command = path.join(root, "scripts/desktop-shell/vhs.sh");
const read = (file) => fs.readFileSync(file, "utf8");

test("animated VHS scales tracking distortion and grain with intensity", () => {
  const source = read(shader);
  assert.match(source, /uniform sampler2D tex;/);
  assert.match(source, /uniform vec2 screenSize;/);
  assert.match(source, /uniform float time;/);
  assert.match(source, /tapeTime \* 24\.0/);
  assert.match(source, /tearCenter = mod\(tapeTime/);
  assert.match(source, /18\.0 \* severe/);
  assert.match(source, /145\.0 \* severe/);
  assert.match(source, /0\.62 \* severe/);
  for (const parameter of ["TRACKING", "CHROMA", "NOISE", "SCANLINES", "SPEED"])
    assert.match(
      source,
      new RegExp("const float VHS_" + parameter + " = 1\\.00;"),
    );
  assert.match(source, /VHS_TRACKING/);
  assert.match(source, /VHS_CHROMA/);
  assert.match(source, /VHS_NOISE/);
  assert.match(source, /VHS_SCANLINES/);
  assert.match(source, /VHS_SPEED/);
  assert.match(source, /const float VHS_DROPOUTS = 0\.00;/);
  assert.match(source, /colour \*= 1\.0 - dropout \* strength \* VHS_DROPOUTS/);
  assert.match(
    source,
    /trackingFlash = .*max\(0\.0, tearDirection\) \* VHS_TRACKING/,
  );
  assert.doesNotMatch(source, /dropout \* strength \* VHS_NOISE/);
  assert.doesNotMatch(source, /pointer_position/);
  assert.match(read(command), /damage_tracking = 0, vfr = false/);
});

test("VHS persists through appearance preferences and defaults to off", () => {
  const module = read(path.join(shell, "default.nix"));
  const preferences = read(path.join(shell, "qml/AppearancePreferences.qml"));
  const ui = read(path.join(shell, "qml/SystemContent.qml"));
  assert.match(
    module,
    /vhsEnabled = lib\.mkOption \{\s*type = lib\.types\.bool;\s*default = false;/,
  );
  assert.match(preferences, /function toggleVhs\(\)/);
  assert.match(preferences, /function setVhsIntensity\(value: real\)/);
  assert.match(preferences, /onVhsControlChanged/);
  assert.match(preferences, /appearance\.applyVhs\(\)/);
  assert.match(
    ui,
    /title: "VHS " \+ Math\.round\(root\.appearance\.vhsIntensity \* 100\)/,
  );
  assert.match(ui, /onActivated: root\.appearance\.toggleVhs\(\)/);
  assert.match(ui, /onDetailsRequested: root\.openVhs\(\)/);
  assert.doesNotMatch(ui, /OpacitySetting \{/);
});

function withCompositor(fn, options = {}) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "desktop-vhs-"));
  try {
    const bin = path.join(tmp, "bin");
    fs.mkdirSync(bin);
    fs.writeFileSync(
      path.join(bin, "hyprctl"),
      [
        "#!/bin/sh",
        'if [ "$1" = getoption ]; then',
        '  case "$2" in',
        '    debug:damage_tracking) printf "int: %s\\nset: true\\n" "$MOCK_DAMAGE" ;;',
        '    debug:vfr) printf "bool: %s\\nset: true\\n" "$MOCK_VFR" ;;',
        '    decoration:screen_shader) printf "str: %s\\nset: true\\n" "$MOCK_SHADER" ;;',
        "    *) exit 1 ;;",
        "  esac",
        'elif [ "$1" = eval ]; then',
        '  printf "%s\\n" "$2" >> "$VHS_CALLS"',
        "else",
        "  exit 1",
        "fi",
      ].join("\n") + "\n",
      { mode: 0o755 },
    );
    const env = {
      ...process.env,
      PATH: bin + ":" + process.env.PATH,
      XDG_RUNTIME_DIR: tmp,
      HYPRLAND_INSTANCE_SIGNATURE: "test-session",
      VHS_CALLS: path.join(tmp, "calls"),
      VHS_SHADER_SOURCE: shader,
      MOCK_DAMAGE: options.damage ?? "2",
      MOCK_VFR: options.vfr ?? "true",
      MOCK_SHADER: options.shader ?? "",
    };
    const run = (...args) =>
      spawnSync("bash", [command, ...args], { env, encoding: "utf8" });
    fn({ tmp, env, run });
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

test("VHS validates intensity and caches only requested shader variants", () => {
  withCompositor(({ tmp, run }) => {
    for (const bad of ["-1", "101", "3.2", "oops"]) {
      assert.equal(run("on", bad).status, 2, bad + " should be rejected");
    }
    assert.equal(run("on", "0").status, 0);
    assert.equal(
      fs.existsSync(path.join(tmp, "desktop-shell", "vhs-state-test-session")),
      false,
    );
    assert.equal(run("on", "45").status, 0);
    assert.equal(run("on", "45").status, 0);
    assert.equal(run("on", "100").status, 0);
    assert.equal(run("off").status, 0);
    const generated = path.join(tmp, "desktop-shell", path.basename(shader));
    assert.deepEqual(fs.readdirSync(generated).sort(), [
      "045-100-100-100-100-100-000.frag",
      "100-100-100-100-100-100-000.frag",
    ]);
    assert.match(
      read(path.join(generated, "045-100-100-100-100-100-000.frag")),
      /VHS_INTENSITY = 0\.45;/,
    );
    assert.match(
      read(path.join(generated, "100-100-100-100-100-100-000.frag")),
      /VHS_INTENSITY = 1\.00;/,
    );
    assert.match(
      read(path.join(tmp, "calls")),
      /damage_tracking = 0, vfr = false/,
    );
  });
});

test("VHS restores original damage tracking, VFR and prior screen shader", () => {
  withCompositor(
    ({ tmp, run }) => {
      const state = path.join(tmp, "desktop-shell", "vhs-state-test-session");
      assert.equal(run("on", "70").status, 0);
      assert.equal(read(state), "1\nfalse\n/custom/original.frag\n");
      assert.equal(run("on", "90").status, 0);
      assert.equal(read(state), "1\nfalse\n/custom/original.frag\n");
      assert.equal(run("off").status, 0);
      assert.equal(fs.existsSync(state), false);
      const calls = read(path.join(tmp, "calls")).trim().split("\n");
      assert.equal(calls.length, 3);
      assert.match(calls[0], /damage_tracking = 0, vfr = false/);
      assert.match(
        calls[0],
        /screen_shader = ".*070-100-100-100-100-100-000\.frag"/,
      );
      assert.match(
        calls[1],
        /screen_shader = ".*090-100-100-100-100-100-000\.frag"/,
      );
      assert.match(calls[2], /damage_tracking = 1, vfr = false/);
      assert.match(calls[2], /screen_shader = "\/custom\/original\.frag"/);
    },
    { damage: "1", vfr: "false", shader: "/custom/original.frag" },
  );
});

test("disabled VHS leaves unrelated shaders untouched and clears legacy VHS", () => {
  withCompositor(
    ({ tmp, run }) => {
      assert.equal(run("off").status, 0);
      assert.equal(fs.existsSync(path.join(tmp, "calls")), false);
    },
    { shader: "/custom/other.frag" },
  );
  withCompositor(({ tmp, run, env }) => {
    const legacy = path.join(
      env.XDG_RUNTIME_DIR,
      "desktop-shell",
      "vhs.frag",
      "045.frag",
    );
    env.MOCK_SHADER = legacy;
    assert.equal(run("off").status, 0);
    assert.match(read(path.join(tmp, "calls")), /screen_shader = ""/);
  });
});

test("independent VHS parameters compile their own variants and validate bounds", () => {
  withCompositor(({ tmp, run }) => {
    for (const invalid of [
      ["80", "-1"],
      ["80", "101"],
      ["80", "80", "bad"],
      ["80", "80", "80", "80", "80", "24"],
      ["80", "80", "80", "80", "80", "251"],
      ["80", "80", "80", "80", "80", "100", "-1"],
      ["80", "80", "80", "80", "80", "100", "101"],
    ]) {
      assert.equal(run("on", ...invalid).status, 2);
    }
    assert.equal(run("on", "80", "0", "50", "75", "25", "150").status, 0);
    const generated = path.join(
      tmp,
      "desktop-shell",
      path.basename(shader),
      "080-000-050-075-025-150-000.frag",
    );
    const source = read(generated);
    for (const [key, value] of Object.entries({
      INTENSITY: "0.80",
      TRACKING: "0.00",
      CHROMA: "0.50",
      NOISE: "0.75",
      SCANLINES: "0.25",
      SPEED: "1.50",
      DROPOUTS: "0.00",
    })) {
      assert.ok(
        source.includes("const float VHS_" + key + " = " + value + ";"),
        key,
      );
    }
    assert.equal(run("off").status, 0);
  });
});

test("VHS tuning exposes correct keyboard focus, pointer and navigation paths", () => {
  const controls = read(path.join(shell, "qml/SystemContent.qml"));
  const tile = read(path.join(shell, "qml/QuickSettingChip.qml"));
  const panel = read(path.join(shell, "qml/VhsPanel.qml"));
  const keymap = read(path.join(shell, "keybindings.nix"));
  const preferences = read(path.join(shell, "qml/AppearancePreferences.qml"));
  const defaults = read(path.join(shell, "default.nix"));
  const runtime = read(path.join(shell, "qml/RuntimeConfig.qml"));

  for (const key of [
    "vhsTracking",
    "vhsChroma",
    "vhsNoise",
    "vhsScanlines",
    "vhsSpeed",
    "vhsDropouts",
  ]) {
    assert.match(defaults, new RegExp(key + " = lib\\.mkOption"));
    assert.match(runtime, new RegExp("property real " + key));
    assert.match(preferences, new RegExp("property real " + key));
    assert.ok(panel.includes('key: "' + key + '"'));
  }
  assert.match(
    controls,
    /detailShortcut: root\.runtime\.shellHint\("SystemContent\.vhsTune"\)/,
  );
  assert.match(controls, /onDetailsRequested: root\.openVhs\(\)/);
  assert.match(controls, /function openVhs\(\)/);
  assert.match(controls, /requestedView === "vhs"/);
  assert.match(
    controls,
    /vhsPanel\.invoke\("handleKey", event\.key, event\.modifiers, event\.isAutoRepeat\)/,
  );
  assert.match(
    controls,
    /shellMatchesHint\("SystemContent\.vhsTune", event\.key, event\.modifiers\)/,
  );
  assert.match(controls, /vhsPanel\.open \? vhsPanel : statusOpen/);
  assert.match(
    controls,
    /implicitHeight: currentDetail \? currentDetail.implicitHeight/,
  );
  assert.match(
    controls,
    /function closeDetails\(\)[\s\S]*?vhsPanel\.closeView\(\)/,
  );
  assert.match(
    tile,
    /TileQuickAction \{[\s\S]*?onActivated: chip\.activated\(\)/,
  );
  assert.match(
    tile,
    /StateLayer \{[\s\S]*?onActivated: chip\.detailShortcut\.length > 0 \? chip\.detailsRequested\(\)/,
  );
  assert.match(panel, /onSelectedRequested: panel\.selectParameter\(index\)/);
  assert.match(panel, /onValueRequested: next => panel\.setParameter/);
  assert.match(
    read(path.join(shell, "qml/ParameterCard.qml")),
    /Accessible\.role: Accessible\.Slider/,
  );
  assert.match(panel, /shellNavigates\("controls", "up", key\)/);
  assert.match(panel, /shellNavigates\("controls", "right", key\)/);
  assert.match(panel, /shellKeyCode\("controls", "Backtab"\)/);
  assert.match(panel, /shellMatchesHint\("VhsPanel\.toggle", key, modifiers\)/);
  assert.match(keymap, /"SystemContent\.vhsTune" = "SHIFT\+P"/);
  assert.match(keymap, /"VhsPanel\.toggle" = "T"/);
  assert.match(keymap, /"VhsPanel\.adjust" = "NAV_HORIZONTAL"/);
  assert.match(keymap, /"VhsPanel\.select"/);
  assert.match(
    preferences,
    /function setVhsParameter\(key: string, value: real\)/,
  );
  assert.match(preferences, /storeOverride\("vhsEnabled", true\)/);
  assert.match(preferences, /vhsApply\.restart\(\)/);
  assert.match(
    defaults,
    /vhsDropouts = lib\.mkOption \{\s*type = lib\.types\.numbers\.between 0\.0 1\.0;\s*default = 0\.0;/,
  );
  assert.match(
    panel,
    /title: "Dropouts",\s*description: "Irregular dark horizontal tape streaks"/,
  );
});

test("high tape noise cannot produce black dropout bands when scanlines and dropouts are zero", () => {
  withCompositor(({ tmp, run }) => {
    assert.equal(run("on", "100", "0", "0", "100", "0", "100", "0").status, 0);
    const quietLines = read(
      path.join(
        tmp,
        "desktop-shell",
        path.basename(shader),
        "100-000-000-100-000-100-000.frag",
      ),
    );
    assert.match(quietLines, /const float VHS_NOISE = 1\.00;/);
    assert.match(quietLines, /const float VHS_SCANLINES = 0\.00;/);
    assert.match(quietLines, /const float VHS_DROPOUTS = 0\.00;/);
    assert.match(
      quietLines,
      /colour \*= 1\.0 - dropout \* strength \* VHS_DROPOUTS/,
    );
    assert.match(
      quietLines,
      /trackingFlash = .*max\(0\.0, tearDirection\) \* VHS_TRACKING/,
    );
    assert.equal(run("on", "100", "0", "0", "0", "0", "100", "100").status, 0);
    const enabledLines = read(
      path.join(
        tmp,
        "desktop-shell",
        path.basename(shader),
        "100-000-000-000-000-100-100.frag",
      ),
    );
    assert.match(enabledLines, /const float VHS_NOISE = 0\.00;/);
    assert.match(enabledLines, /const float VHS_DROPOUTS = 1\.00;/);
    assert.equal(run("off").status, 0);
  });
});
