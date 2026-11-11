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
  const lock = nix.match(/linux-desktop-lock = \{([\s\S]*?)\n {8}\};/);
  assert.ok(lock, "the existing on-demand lock service is retained");
  assert.match(lock[1], /X-SwitchMethod = "keep-old"/);
  assert.match(lock[1], /Restart = "no"/);
  assert.doesNotMatch(lock[1], /X-RestartIfChanged/);
  assert.doesNotMatch(lock[1], /Install\.WantedBy/);
  assert.match(nix, /exec systemctl --user start linux-desktop-lock\.service/);
});

test("the lock service cannot retire during asynchronous acquisition or a rebuild", () => {
  const screen = fs.readFileSync(path.join(root, "qml/LockScreen.qml"), "utf8");
  const lock = nix.match(/linux-desktop-lock = \{([\s\S]*?)\n {8}\};/);
  assert.ok(lock);
  assert.match(lock[1], /X-SwitchMethod = "keep-old"/);
  assert.match(lock[1], /Restart = "no"/);
  assert.doesNotMatch(lock[1], /Install\.WantedBy|X-RestartIfChanged/);
  assert.match(qml, /armed = true;\s*lockScreen\.lockSession\(\)/);
  assert.doesNotMatch(qml, /if \(!lockScreen\.locked\)\s*stopLockService\(\)/);
  assert.match(
    qml,
    /if \(!armed \|\| !authenticated \|\| lockScreen\.locked\)/,
  );
  assert.match(screen, /signal unlockAuthorized(?:\(\))?/);
  assert.match(screen, /lock\.locked = false;\s*lock\.unlockAuthorized\(\)/);
  assert.match(qml, /function onUnlockAuthorized\(\): void/);
  assert.match(qml, /root\.authenticated = true/);
  assert.match(qml, /if \(root\.authenticated && !lockScreen\.locked\)/);
  assert.match(qml, /interval: 500/);
  assert.match(qml, /onTriggered: root\.stopLockService\(\)/);
  assert.match(
    qml,
    /Quickshell\.execDetached\(\["systemctl", "--user", "stop", "--no-block", "linux-desktop-lock\.service"\]\)/,
  );
  assert.doesNotMatch(qml, /Qt\.quit\(\)/);
  assert.doesNotMatch(qml, /runtime\.lockSession, "unlocked"/);
});

test("the shutdown guard ignores transient acquisition states and runs once after authentication", () => {
  const begin = qml.indexOf("function stopLockService(): void {");
  assert.notEqual(begin, -1);
  const open = qml.indexOf("{", begin);
  let depth = 0;
  let close = -1;
  for (let i = open; i < qml.length; i++) {
    if (qml[i] === "{") depth++;
    else if (qml[i] === "}" && --depth === 0) {
      close = i;
      break;
    }
  }
  assert.ok(close > open);
  const body = qml.slice(open + 1, close);
  const stop = new Function("state", "Quickshell", `with (state) { ${body} }`);
  const state = {
    armed: true,
    authenticated: false,
    lockScreen: { locked: false },
  };
  const calls = [];
  const quickshell = { execDetached: (args) => calls.push(args) };

  stop(state, quickshell);
  assert.equal(
    state.armed,
    true,
    "unlocked before acquisition must stay alive",
  );
  assert.equal(calls.length, 0);

  state.lockScreen.locked = true;
  state.authenticated = true;
  stop(state, quickshell);
  assert.equal(
    state.armed,
    true,
    "even authenticated, the lock must release first",
  );
  assert.equal(calls.length, 0);

  state.lockScreen.locked = false;
  stop(state, quickshell);
  assert.equal(state.armed, false);
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0], [
    "systemctl",
    "--user",
    "stop",
    "--no-block",
    "linux-desktop-lock.service",
  ]);
  stop(state, quickshell);
  assert.equal(calls.length, 1, "retirement is idempotent");
});

test("Session uses the lock screen vector glyph and displays a coloured action icon at rest", () => {
  const actionButton = fs.readFileSync(
    path.join(root, "qml/SessionActionButton.qml"),
    "utf8",
  );
  const lockScreen = fs.readFileSync(
    path.join(root, "qml/LockScreen.qml"),
    "utf8",
  );
  assert.match(lockScreen, /LockGlyph \{/);
  assert.match(actionButton, /LockGlyph \{\s*visible: button\.lockGlyph/);
  assert.match(session, /lockGlyph: modelData\.id === "lock"/);
  assert.match(
    actionButton,
    /color: button\.armed \? button\.theme\.warning : button\.accentColor/,
  );
  assert.doesNotMatch(
    actionButton,
    /text: button\.icon\s+color: button\.armed \? button\.theme\.warning : button\.selected/,
  );
});

test("Session keycaps stay outside the morphing surface and Restore uses the shared active tile style", () => {
  const button = fs.readFileSync(
    path.join(root, "qml/SessionActionButton.qml"),
    "utf8",
  );
  const content = fs.readFileSync(
    path.join(root, "qml/SystemContent.qml"),
    "utf8",
  );
  assert.match(session, /shortcut: String\(actionIndex \+ 1\)/);
  assert.match(button, /KeyHint \{[\s\S]*?shortcut: button\.shortcut/);
  assert.match(content, /event\.key >= Qt\.Key_1 && event\.key <= Qt\.Key_6/);
  assert.match(
    content,
    /sessionPanel\.invoke\("activateIndex", event\.key - Qt\.Key_1\)/,
  );
  assert.match(session, /function activateIndex\(index: int\): void \{/);
  assert.doesNotMatch(button, /statusLabel|statusText|"ON"|"OFF"/);
  assert.doesNotMatch(session, /statusLabel:/);
  assert.match(
    session,
    /active: modelData\.id === "restore" && panel\.restoreWindowsOnExit/,
  );
  assert.match(button, /luminous: button\.active/);
  assert.match(button, /outlined: button\.active/);
  assert.match(
    button,
    /borderColor: button\.armed \? button\.theme\.warning : button\.selected \|\| button\.active \? button\.accentColor/,
  );
  assert.match(
    button,
    /cornerRadius: button\.selected \|\| pointer\.pointerHovered \? width \/ 2/,
  );
  assert.match(
    button,
    /KeyHint \{\s*anchors \{\s*top: parent\.top\s*right: parent\.right/,
  );
  assert.ok(
    button.indexOf("    KeyHint {") > button.indexOf("    ShellSurface {"),
  );
  assert.ok(button.indexOf("    KeyHint {") < button.lastIndexOf("    Text {"));
  assert.doesNotMatch(
    button,
    /KeyHint \{[\s\S]*?anchors \{\s*top: parent\.top\s*right: parent\.right\s*margins:/,
  );
  assert.match(session, /shortcut: "1-6",\s*label: "Direct action"/);
});
