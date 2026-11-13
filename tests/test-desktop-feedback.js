const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const qmlDir = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(qmlDir, name), "utf8");
const keyboard = vm.runInNewContext(
  read("KeyboardSemantics.js") + "\n({snapshot,lockState})",
);
const feedback = vm.runInNewContext(
  read("FeedbackSemantics.js") + "\n({symbol,stateLabel})",
);

test("a non-keyboard main device never replaces real keyboard state", () => {
  const data = {
    keyboards: [
      { name: "power-button", main: true, capsLock: false, numLock: false },
      {
        name: "keyboard",
        main: false,
        capsLock: true,
        numLock: false,
        active_keymap: "Layout",
      },
    ],
  };
  const state = keyboard.snapshot(data);
  assert.equal(state.deviceCount, 1);
  assert.equal(state.deviceName, "keyboard");
  assert.equal(state.capsState, "on");
  assert.equal(state.numState, "off");
  assert.equal(state.layoutName, "Layout");
});

test("multiple keyboards do not silently collapse conflicting state to off", () => {
  const state = keyboard.snapshot({
    keyboards: [
      { name: "one", capsLock: true, numLock: false, layout: "Alpha" },
      { name: "two", capsLock: false, numLock: false, layout: "Beta" },
    ],
  });
  assert.equal(state.capsState, "mixed");
  assert.equal(state.numState, "off");
  assert.equal(state.layoutName, "Mixed layouts");
  assert.equal(state.deviceCount, 2);
  assert.equal(
    keyboard.snapshot({ keyboards: [{ name: "power-button", main: true }] }),
    null,
  );
  assert.equal(keyboard.snapshot({ keyboards: null }), null);
});

test("all keyboard states and icons have distinct semantic outcomes", () => {
  assert.deepEqual(["on", "off", "mixed", "unknown"].map(feedback.stateLabel), [
    "ON",
    "OFF",
    "MIXED",
    "UNKNOWN",
  ]);
  assert.notEqual(
    feedback.symbol("keyboard", false, 0, "on"),
    feedback.symbol("keyboard", false, 0, "off"),
  );
  assert.notEqual(
    feedback.symbol("microphone", true, 50),
    feedback.symbol("microphone", false, 50),
  );
  assert.notEqual(
    feedback.symbol("volume", true, 50),
    feedback.symbol("volume", false, 50),
  );
});

test("QML functions use supported typed-argument syntax", () => {
  for (const component of [
    "KeyboardState.qml",
    "StatusPeek.qml",
    "StatusContent.qml",
    "shell.qml",
    "OsdState.qml",
    "ResizeOverlay.qml",
  ]) {
    assert.doesNotMatch(
      read(component),
      /function\s+\w+\([^)]*:\s*\w+\s*=/,
      `${component} must not combine typed arguments with defaults`,
    );
  }
});

test("keyboard readback is owned outside the transient OSD", () => {
  const state = read("KeyboardState.qml");
  const osd = read("OsdState.qml");
  assert.match(state, /KeyboardSemantics\.snapshot\(data\)/);
  assert.match(state, /function refresh\(reason: string\)/);
  assert.match(state, /query\.exec\(\[runtime\.hyprctl, "-j", "devices"\]\)/);
  assert.doesNotMatch(state, /dispatch\(|sendKey|toggleCaps|toggleNum/);
  assert.match(osd, /onRefreshed\(reason: string\)/);
  assert.doesNotMatch(osd, /Process keyboardQuery/);
  assert.match(osd, /function showMicrophone\(\)/);
  assert.match(osd, /onMicrophoneMutedChanged\(\): void/);
  assert.match(osd, /deferredFeedback/);
});

test("inspection is reachable through canonical shortcut, palette and status island", () => {
  const shell = read("shell.qml");
  const island = read("SystemIsland.qml");
  const bar = read("AmbientBar.qml");
  const peek = read("StatusPeek.qml");
  const repo = path.join(__dirname, "../modules/desktop/hyprland");
  const keybindings = fs.readFileSync(
    path.join(repo, "keybindings.nix"),
    "utf8",
  );
  const nix = fs.readFileSync(path.join(repo, "shell/default.nix"), "utf8");
  assert.match(
    keybindings,
    /id = "status\.inspect";\s*action = global "linux-desktop:status-peek"/,
  );
  assert.match(nix, /statusInspect = navigationKey "status\.inspect"/);
  assert.match(shell, /name: "status-peek"/);
  assert.match(shell, /id: "status\.inspect"/);
  assert.match(
    bar,
    /onInspectRequested: bars\.systemStatusRequested\(bar\.modelData\)/,
  );
  assert.match(island, /acceptedButtons: Qt\.LeftButton \| Qt\.RightButton/);
  assert.match(peek, /keyboard\.refresh\("inspect"\)/);
  assert.match(peek, /WlrKeyboardFocus\.OnDemand/);
  assert.doesNotMatch(
    peek,
    /toggleWifi|setVolume|setPercent|toggleMuted|toggleIdle/,
  );
});

test("active resize owns local inspection and reports observed geometry", () => {
  const resize = read("ResizeOverlay.qml");
  const shell = read("shell.qml");
  assert.match(
    shell,
    /if \(resizeOverlay\.open\) \{\s*resizeOverlay\.inspectOpen = !resizeOverlay\.inspectOpen/,
  );
  assert.match(resize, /WlrKeyboardFocus\.Exclusive/);
  assert.match(resize, /event\.key === Qt\.Key_S/);
  assert.match(resize, /keyboard\.refresh\("inspect"\)/);
  assert.match(resize, /"-j", "activewindow"/);
  assert.match(resize, /window\.size\[0\]/);
  assert.doesNotMatch(resize, /lastAction = `\$\{x > 0 \?/);
  assert.match(
    shell,
    /screen: root\.resizeTargetScreen \|\| screens\.focusedScreen/,
  );
});

test("OSD and modes use the shared upper frame anchor without overlapping", () => {
  const osd = read("OsdPopup.qml");
  const shell = read("shell.qml");
  const frame = read("DesktopFrame.qml");
  assert.match(osd, /anchors\.top: true/);
  assert.doesNotMatch(osd, /anchors\.bottom: true/);
  assert.match(
    osd,
    /readonly property bool exposedNow: osd\.visible && !suspended/,
  );
  assert.match(
    shell,
    /suspended: statusPeek\.open \|\| resizeOverlay\.open \|\| expansionState\.hasCurrent/,
  );
  assert.match(frame, /\[args\[9\], args\[10\], args\[11\]\]/);
  assert.match(read("StatusPeek.qml"), /frameEnabled && !hubVisible/);
});
