const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const nix = fs.readFileSync(path.join(root, "default.nix"), "utf8");
const session = fs.readFileSync(
  path.join(root, "qml/SessionPanel.qml"),
  "utf8",
);
const actions = fs.readFileSync(path.join(root, "qml/Actions.qml"), "utf8");
const qml = fs.readFileSync(path.join(root, "qml/lock.qml"), "utf8");

test("lock launcher and desktop shell share the same native visuals import", () => {
  const imports = nix.match(/export QML_IMPORT_PATH=[^\n]*/g) || [];
  assert.equal(
    imports.length,
    3,
    "desktop, development, and lock launcher must load the native module",
  );
  assert.equal(imports[0], imports[1]);
  assert.equal(imports[1], imports[2]);
  assert.match(nix, /lockServiceLauncher = pkgs\.writeShellApplication/);
  assert.match(
    nix,
    /exec qs --no-duplicate --path .*productionShellPath.*\/lock\.qml/,
  );
  assert.match(nix, /ExecStart = lib\.getExe lockServiceLauncher/);
});
test("session widget and global keybind use the same lock command", () => {
  assert.match(nix, /lockSession = lib\.getExe lockCommand/);
  assert.match(nix, /exec systemctl --user start linux-desktop-lock\.service/);
  assert.match(session, /Quickshell\.execDetached\(\[runtime\.lockSession\]\)/);
  assert.match(
    actions,
    /function lockSession\(\): void \{[\s\S]*?Quickshell\.execDetached\(\[runtime\.lockSession\]\)/,
  );
  assert.match(qml, /lockScreen\.lockSession\(\)/);
});

test("Home Manager switches preserve an active session lock without starting a new one", () => {
  const lock = nix.match(/linux-desktop-lock = \{([\s\S]*?)\n        \};/);
  assert.ok(lock, "the existing on-demand lock service is retained");
  assert.match(lock[1], /X-SwitchMethod = "keep-old"/);
  assert.match(lock[1], /Restart = "no"/);
  assert.doesNotMatch(lock[1], /X-RestartIfChanged/);
  assert.doesNotMatch(lock[1], /Install\.WantedBy/);
  assert.match(nix, /exec systemctl --user start linux-desktop-lock\.service/);
});

test("successful unlock stops the on-demand lock service so another lock can start", () => {
  assert.match(nix, /exec systemctl --user start linux-desktop-lock\.service/);
  assert.match(qml, /armed = true;\s*lockScreen\.lockSession\(\)/);
  assert.match(qml, /if \(!lockScreen\.locked\)\s*stopLockService\(\)/);
  assert.match(qml, /function stopLockService\(\): void/);
  assert.match(qml, /if \(root\.armed && !lockScreen\.locked\)/);
  assert.match(qml, /armed = false;/);
  assert.match(qml, /root\.stopLockService\(\)/);
  assert.match(
    qml,
    /Quickshell\.execDetached\(\["systemctl", "--user", "stop", "--no-block", "linux-desktop-lock\.service"\]\)/,
  );
  assert.doesNotMatch(qml, /Qt\.quit\(\)/);
  assert.doesNotMatch(qml, /runtime\.lockSession, "unlocked"/);
});
