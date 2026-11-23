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

test("VHS uses the damage-tracked screen shader path", () => {
  const source = read(shader);
  assert.match(source, /uniform sampler2D tex;/);
  assert.match(source, /uniform vec2 screenSize;/);
  assert.match(source, /VHS_INTENSITY/);
  assert.doesNotMatch(source, /uniform\s+\w+\s+time\s*;/);
  assert.doesNotMatch(source, /uniform\s+\w+\s+pointer_position\s*;/);
  assert.doesNotMatch(read(command), /damage_tracking|vfr/);
});

test("VHS persists through the existing appearance preferences with Nix off by default", () => {
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
  assert.match(ui, /onToggleRequested: root\.appearance\.toggleVhs\(\)/);
});

test("controller rejects invalid intensities and builds cached shader variants", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "desktop-vhs-"));
  try {
    const bin = path.join(tmp, "bin");
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, "hyprctl"), '#!/bin/sh\nprintf "%s\\n" "$*" >> "$VHS_CALLS"\n', { mode: 0o755 });
    const env = {
      ...process.env,
      PATH: bin + ":" + process.env.PATH,
      XDG_RUNTIME_DIR: tmp,
      VHS_CALLS: path.join(tmp, "calls"),
      VHS_SHADER_SOURCE: shader,
    };
    const run = (...args) => spawnSync("bash", [command, ...args], { env, encoding: "utf8" });
    for (const bad of ["-1", "101", "3.2", "oops"]) {
      assert.equal(run("on", bad).status, 2, bad + " should be rejected");
    }
    for (const level of ["0", "45", "45", "100"]) {
      assert.equal(run("on", level).status, 0);
    }
    assert.equal(run("off").status, 0);
    const state = path.join(tmp, "desktop-shell", path.basename(shader));
    assert.deepEqual(fs.readdirSync(state).sort(), ["000.frag", "045.frag", "100.frag"]);
    assert.match(read(path.join(state, "000.frag")), /const float VHS_INTENSITY = 0\.00;/);
    assert.match(read(path.join(state, "045.frag")), /const float VHS_INTENSITY = 0\.45;/);
    assert.match(read(path.join(state, "100.frag")), /const float VHS_INTENSITY = 1\.00;/);
    const calls = read(path.join(tmp, "calls")).trim().split("\n");
    assert.equal(calls.length, 5);
    assert.match(calls[0], /screen_shader.*000\.frag/);
    assert.match(calls[4], /screen_shader = ""/);
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
