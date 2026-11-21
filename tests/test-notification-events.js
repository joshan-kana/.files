const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { spawnSync } = require("node:child_process");

const root = path.join(__dirname, "../");
const qml = (name) =>
  fs.readFileSync(
    path.join(root, "modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );
const script = (name) => path.join(root, "scripts/linux-desktop", name);

test("service-backed event notifications share the freedesktop server, not island or popup code", () => {
  const events = qml("EventNotifications.qml");
  const shell = qml("shell.qml");
  const nix = fs.readFileSync(
    path.join(root, "modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  assert.match(events, /required property NotificationState notifications/);
  assert.match(events, /required property SystemState system/);
  assert.match(events, /required property PowerProfileState powerProfile/);
  assert.match(events, /"--app-name=Desktop " \+ source/);
  assert.match(
    events,
    /onStreamFinished:[\s\S]*?notice\.actionRequested\(notice\.actionTarget\)/,
  );
  assert.match(events, /"monitoraddedv2"/);
  assert.match(events, /onOutputSignatureChanged: connectedDevice\(false\)/);
  assert.match(events, /onInputSignatureChanged: connectedDevice\(true\)/);
  assert.match(events, /onConnectedChanged: if \(ready\)/);
  assert.match(events, /onBatteryStateChanged:/);
  assert.match(events, /onBatteryBandChanged:/);
  assert.match(events, /initialSnapshot: Timer/);
  assert.match(events, /interval: 6000/);
  assert.doesNotMatch(
    events,
    /PanelWindow|PopupWindow|WlrLayershell|NotificationServer/,
  );
  assert.match(shell, /EventNotifications \{/);
  assert.match(nix, /notifySend = lib\.getExe' pkgs\.libnotify "notify-send"/);
  assert.match(qml("RuntimeConfig.qml"), /property string notifySend: ""/);
});

test("a visible notification can be targeted from the global keyboard without grabbing toast focus", () => {
  const state = qml("NotificationState.qml");
  const center = qml("NotificationContent.qml");
  const actions = qml("Actions.qml");
  const shell = qml("shell.qml");
  const registry = fs.readFileSync(
    path.join(root, "modules/desktop/hyprland/keybindings.nix"),
    "utf8",
  );
  assert.match(state, /function latestPopup\(\): var/);
  assert.match(state, /function requestFocusLatest\(\): void/);
  assert.match(state, /function dismissLatestPopup\(\): void/);
  assert.match(center, /function focusRequested\(\): void/);
  assert.match(
    center,
    /notificationState\.recordKey\(item\) === notificationState\.focusRecordId/,
  );
  assert.match(
    actions,
    /notificationState\.requestFocusLatest\(\);\s*notificationState\.hidePopup\(\)/,
  );
  assert.match(
    shell,
    /name: "notifications-dismiss"[\s\S]*?onPressed: notifications\.dismissLatestPopup\(\)/,
  );
  assert.match(
    registry,
    /id = "notifications\.dismissLatest";\s*action = global "linux-desktop:notifications-dismiss"/,
  );
  assert.doesNotMatch(
    qml("NotificationPopup.qml"),
    /WlrKeyboardFocus\.Exclusive|Keys\.onPressed/,
  );
});

test("saved screenshots and videos keep native actions and open the selectable OCR viewer", () => {
  const notice = fs.readFileSync(script("capture-notify.sh"), "utf8");
  const open = fs.readFileSync(script("open-capture.sh"), "utf8");
  const shell = qml("shell.qml");
  const lib = qml("RecordingLibrary.qml");
  assert.match(notice, /--action=text="Select text"/);
  assert.match(notice, /--action=copy=Copy/);
  assert.match(notice, /--action=edit=Markup/);
  assert.match(notice, /--action=edit=Trim/);
  assert.match(
    open,
    /quickshell ipc --path "\$LINUX_DESKTOP_SHELL_PATH" call desktop showCaptureText "\$name"/,
  );
  assert.match(shell, /function showCaptureText\(name: string\): void/);
  assert.match(
    shell,
    /actions\.showSystem\(null, null, "recordings:" \+ name\)/,
  );
  assert.match(
    qml("SystemContent.qml"),
    /requestedView\.startsWith\("recordings:"\)/,
  );
  assert.match(
    qml("SystemContent.qml"),
    /recordingsPanel\.queueText\(filename\)/,
  );
  assert.doesNotMatch(shell, /captureTextSerial|captureTextName/);
  assert.match(lib, /function queueText\(name: string\): void/);
  assert.match(lib, /function openPendingText\(\): void/);
  assert.match(lib, /if \(listProcess\.running\)\s+return;/);
  assert.match(
    qml("SystemContent.qml"),
    /if \(!requestedView\.startsWith\("recordings:"\)\)\s+markDetail\("recordings"\)/,
  );
  assert.match(lib, /showText\(\)/);
});

test("OCR notification action rejects unrelated files and preserves the capture identity", () => {
  const folder = fs.mkdtempSync(
    path.join(os.tmpdir(), "desktop-capture-action-"),
  );
  const bin = path.join(folder, "bin");
  fs.mkdirSync(bin);
  const qs = path.join(bin, "quickshell");
  fs.writeFileSync(qs, "#!/bin/sh\nprintf '%s\\n' \"$@\"\n");
  fs.chmodSync(qs, 0o755);
  const pictures = path.join(folder, "Pictures");
  const image = "Screenshot-20261121-123456-42.png";
  const images = path.join(pictures, "Screenshots");
  fs.mkdirSync(images, { recursive: true });
  fs.writeFileSync(path.join(images, image), "file");
  try {
    const env = {
      ...process.env,
      PATH: bin + ":" + process.env.PATH,
      XDG_PICTURES_DIR: pictures,
      LINUX_DESKTOP_SHELL_PATH: "/nix/store/valid-qml",
    };
    const valid = spawnSync(
      "bash",
      [script("open-capture.sh"), "text-screenshot", path.join(images, image)],
      { env, encoding: "utf8" },
    );
    assert.equal(valid.status, 0, valid.stderr);
    assert.equal(
      valid.stdout,
      "ipc\n--path\n/nix/store/valid-qml\ncall\ndesktop\nshowCaptureText\n" +
        image +
        "\n",
    );
    const invalid = spawnSync(
      "bash",
      [script("open-capture.sh"), "text-screenshot", "/tmp/" + image],
      { env, encoding: "utf8" },
    );
    assert.notEqual(invalid.status, 0);
    assert.equal(invalid.stdout, "");
  } finally {
    fs.rmSync(folder, { recursive: true, force: true });
  }
});
