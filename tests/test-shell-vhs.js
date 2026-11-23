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
  assert.match(source, /time \* 24\.0/);
  assert.match(source, /tearCenter = mod\(time/);
  assert.match(source, /18\.0 \* severe/);
  assert.match(source, /145\.0 \* severe/);
  assert.match(source, /0\.62 \* severe/);
  assert.doesNotMatch(source, /pointer_position/);
  assert.match(read(command), /damage_tracking = 0, vfr = false/);
});

test("VHS persists through appearance preferences and defaults to off", () => {
  const module = read(path.join(shell, "default.nix"));
  const preferences = read(path.join(shell, "qml/AppearancePreferences.qml"));
  const ui = read(path.join(shell, "qml/SystemContent.qml"));
  assert.match(module, /vhsEnabled = lib\.mkOption \{\s*type = lib\.types\.bool;\s*default = false;/);
  assert.match(preferences, /function toggleVhs\(\)/);
  assert.match(preferences, /function setVhsIntensity\(value: real\)/);
  assert.match(preferences, /onVhsControlChanged/);
  assert.match(preferences, /appearance\.applyVhs\(\)/);
  assert.match(ui, /label: "VHS tape"/);
  assert.match(ui, /minimumValue: 0/);
  assert.match(ui, /selectedSlider === "vhs"/);
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
    assert.equal(fs.existsSync(path.join(tmp, "desktop-shell", "vhs-state-test-session")), false);
    assert.equal(run("on", "45").status, 0);
    assert.equal(run("on", "45").status, 0);
    assert.equal(run("on", "100").status, 0);
    assert.equal(run("off").status, 0);
    const generated = path.join(tmp, "desktop-shell", path.basename(shader));
    assert.deepEqual(fs.readdirSync(generated).sort(), ["045.frag", "100.frag"]);
    assert.match(read(path.join(generated, "045.frag")), /VHS_INTENSITY = 0\.45;/);
    assert.match(read(path.join(generated, "100.frag")), /VHS_INTENSITY = 1\.00;/);
    assert.match(read(path.join(tmp, "calls")), /damage_tracking = 0, vfr = false/);
  });
});

test("VHS restores original damage tracking, VFR and prior screen shader", () => {
  withCompositor(({ tmp, run }) => {
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
    assert.match(calls[0], /screen_shader = ".*070\.frag"/);
    assert.match(calls[1], /screen_shader = ".*090\.frag"/);
    assert.match(calls[2], /damage_tracking = 1, vfr = false/);
    assert.match(calls[2], /screen_shader = "\/custom\/original\.frag"/);
  }, { damage: "1", vfr: "false", shader: "/custom/original.frag" });
});

test("disabled VHS leaves unrelated shaders untouched and clears legacy VHS", () => {
  withCompositor(({ tmp, run }) => {
    assert.equal(run("off").status, 0);
    assert.equal(fs.existsSync(path.join(tmp, "calls")), false);
  }, { shader: "/custom/other.frag" });
  withCompositor(({ tmp, run, env }) => {
    const legacy = path.join(env.XDG_RUNTIME_DIR, "desktop-shell", "vhs.frag", "045.frag");
    env.MOCK_SHADER = legacy;
    assert.equal(run("off").status, 0);
    assert.match(read(path.join(tmp, "calls")), /screen_shader = ""/);
  });
});
