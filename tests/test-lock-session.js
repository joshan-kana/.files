const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const nix = fs.readFileSync(path.join(root, "default.nix"), "utf8");
const lockCommand = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/scripts/lock.sh"),
  "utf8",
);
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
  assert.match(
    lockCommand,
    /systemctl --user start linux-desktop-lock\.service/,
  );
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
  assert.match(
    lockCommand,
    /systemctl --user start linux-desktop-lock\.service/,
  );
});

test("the lock service cannot retire during asynchronous acquisition or a rebuild", () => {
  const screen = fs.readFileSync(path.join(root, "qml/LockScreen.qml"), "utf8");
  const lock = nix.match(/linux-desktop-lock = \{([\s\S]*?)\n {8}\};/);
  assert.ok(lock);
  assert.match(lock[1], /X-SwitchMethod = "keep-old"/);
  assert.match(lock[1], /Restart = "no"/);
  assert.doesNotMatch(lock[1], /Install\.WantedBy|X-RestartIfChanged/);
  assert.match(
    qml,
    /armed = true;\s*publishLockState\("requested"\);\s*lockScreen\.lockSession\(\)/,
  );
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

test("Session uses animated shared tile hints and physical QWE/ASD action positions", () => {
  const button = fs.readFileSync(
    path.join(root, "qml/SessionActionButton.qml"),
    "utf8",
  );
  const hint = fs.readFileSync(path.join(root, "qml/TileKeyHint.qml"), "utf8");
  const content = fs.readFileSync(
    path.join(root, "qml/SystemContent.qml"),
    "utf8",
  );

  for (const [id, key] of [
    ["lock", "Q"],
    ["suspend", "W"],
    ["logout", "E"],
    ["reboot", "A"],
    ["poweroff", "S"],
    ["restore", "D"],
  ])
    assert.match(session, new RegExp(`id: "${id}",\\s*shortcut: "${key}"`));
  assert.match(session, /shortcut: modelData\.shortcut/);
  assert.match(session, /function activateShortcut\(key: int\): bool \{/);
  assert.match(
    session,
    /entries\.findIndex\(entry => entry\.shortcut === shortcut\)/,
  );
  assert.match(
    content,
    /sessionPanel\.invoke\("activateShortcut", event\.key\) === true/,
  );
  assert.match(content, /key: sessionPanel\.actionShortcutLegend/);
  assert.match(session, /actionShortcutLegend: entries\.slice\(0, 3\)/);
  assert.match(session, /function activateIndex\(index: int\): void \{/);
  assert.doesNotMatch(session, /String\(actionIndex \+ 1\)|shortcut: "1-6"/);

  assert.match(
    button,
    /TileKeyHint \{[\s\S]*?motion: button\.motion[\s\S]*?circular: button\.selected \|\| pointer\.pointerHovered/,
  );
  assert.match(
    button,
    /cornerRadius: button\.selected \|\| pointer\.pointerHovered \? width \/ 2/,
  );
  assert.match(
    hint,
    /anchors \{\s*top: parent\.top\s*right: parent\.right\s*topMargin: animatedInset\s*rightMargin: animatedInset/,
  );
  assert.match(
    hint,
    /property real animatedInset: circular \? circleInset : cornerInset/,
  );
  assert.match(
    hint,
    /Behavior on animatedInset \{\s*Anim \{[\s\S]*?type: Anim\.FastSpatial/,
  );
  assert.match(hint, /Math\.min\(parent\.width, parent\.height\)/);

  // The full keycap fits inside a circular tile with room for its outline.
  const radius = 115 / 2;
  const inset = radius * (1 - Math.SQRT1_2) + 2 + 4;
  assert.ok(Math.hypot(radius - inset, radius - inset) < radius - 2);

  assert.match(
    session,
    /active: modelData\.id === "restore" && panel\.restoreWindowsOnExit/,
  );
  assert.match(button, /luminous: button\.active/);
  assert.match(button, /outlined: button\.active/);
  assert.doesNotMatch(button, /statusLabel|statusText|"ON"|"OFF"/);
  assert.match(session, /Item \{\s*id: hintRegion\s*width: buttonGrid\.width/);
  assert.match(
    session,
    /KeyHint \{\s*id: moveHint[\s\S]*?shortcut: "HJKL"\s*label: "Move"/,
  );
  assert.match(
    session,
    /KeyHint \{\s*id: actionHint[\s\S]*?shortcut: "ENTER"\s*label: panel\.armedAction\.length > 0 \? "Confirm" : "Activate"/,
  );
});

test("Escape cancels an armed Session action before backing out", () => {
  const content = fs.readFileSync(
    path.join(root, "qml/SystemContent.qml"),
    "utf8",
  );
  const host = fs.readFileSync(
    path.join(root, "qml/ShellExpansionHost.qml"),
    "utf8",
  );
  const deferred = fs.readFileSync(
    path.join(root, "qml/DeferredDetail.qml"),
    "utf8",
  );
  assert.match(
    deferred,
    /readonly property string armedAction: panel && typeof panel\.armedAction === "string" \? panel\.armedAction : ""/,
  );
  assert.match(
    deferred,
    /readonly property string actionShortcutLegend: panel && typeof panel\.actionShortcutLegend === "string" \? panel\.actionShortcutLegend : ""/,
  );
  assert.match(
    session,
    /function cancelConfirmation\(\): void \{\s*armTimer\.stop\(\);\s*armedAction = "";\s*statusText = "";\s*statusError = false;/,
  );
  assert.match(
    content,
    /readonly property bool sessionConfirmationPending: sessionPanel\.open && sessionPanel\.armedAction\.length > 0/,
  );
  assert.match(
    content,
    /if \(sessionPanel\.open\) \{[\s\S]*?event\.key === Qt\.Key_Escape[\s\S]*?if \(sessionPanel\.armedAction\.length > 0\)\s*sessionPanel\.invoke\("cancelConfirmation"\);\s*else\s*root\.backFromDetail\(\)/,
  );
  assert.match(
    content,
    /action: sessionPanel\.armedAction\.length > 0 \? "Cancel confirmation"/,
  );
  assert.match(host, /sessionConfirmationPending\) \? "Cancel"/);
  assert.match(
    content,
    /if \(root\.helpOpen\) \{[\s\S]*?sessionPanel\.open && sessionPanel\.armedAction\.length > 0\)\s*sessionPanel\.invoke\("cancelConfirmation"\);\s*root\.helpOpen = false;/,
  );
  const cancellation =
    session.match(
      /function cancelConfirmation\(\): void \{([\s\S]*?)\n {4}\}/,
    )?.[1] || "";
  assert.doesNotMatch(
    cancellation,
    /execute\(|closeView\(|sessionCommand|execDetached|backFromDetail/,
  );
});

test("lock request is published before compositor acquisition, and unlock requires authentication", () => {
  const shell = fs.readFileSync(
    path.join(root, "qml/NotificationState.qml"),
    "utf8",
  );
  assert.match(lockCommand, /printf 'requested\\n' >\s*"\$temp"/);
  assert.match(
    qml,
    /publishLockState\("requested"\);\s*lockScreen\.lockSession\(\)/,
  );
  assert.match(
    qml,
    /if \(root\.authenticated && !lockScreen\.locked\) \{\s*root\.publishLockState\("unlocked"\)/,
  );
  assert.match(
    shell,
    /readonly property bool locked: \["requested", "locked"\]\.includes\(lockState\.text\(\)\.trim\(\)\)/,
  );
  assert.match(shell, /onLockedChanged: \{\s*if \(locked\)\s*hidePopup\(\)/);
});
