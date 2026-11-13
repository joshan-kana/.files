const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("notification toasts render above the Controls hub without changing popup geometry or input masking", () => {
  const popup = qml("NotificationPopup.qml");
  const hub = qml("ShellExpansionHost.qml");
  const root = qml("shell.qml");
  assert.match(hub, /WlrLayershell\.layer: WlrLayer\.Overlay/);
  assert.ok(
    root.indexOf("ShellExpansionHost {") < root.indexOf("NotificationPopups {"),
  );
  const outputs = qml("NotificationPopups.qml");
  assert.match(outputs, /model: Quickshell.screens/);
  assert.match(outputs, /delegate: NotificationPopup/);
  assert.match(outputs, /onCenterRequested: outputs.centerRequested\(screen\)/);
  assert.match(popup, /WlrLayershell\.layer: WlrLayer\.Overlay/);
  assert.match(
    popup,
    /WlrLayershell\.namespace: "linux-desktop-notification-popup"/,
  );
  assert.match(popup, /mask: surfaceLifecycle\.inputRegion/);
  assert.match(popup, /interactiveItem: toastInputArea/);
  assert.match(popup, /readonly property int maxToastSlots:/);
  // A logically retained eviction must never paint behind a moving live card:
  // that previously made text from two different notifications slide through
  // each other when a fourth notification arrived.
  assert.match(
    popup,
    /visible: !evicted && outputName === \(popup\.screen \? popup\.screen\.name : ""\) && slot < popup\.maxToastSlots/,
  );
  assert.match(popup, /onVisibleChanged: popup\.contourEpoch\+\+/);
  assert.match(popup, /if \(toast && toast\.visible\)/);
  assert.match(
    root,
    /hubVisible: expansionState\.hasCurrent \|\| expansionHost\.closing/,
  );
  assert.match(
    popup,
    /readonly property bool frameAttached: frameConnected && !hubOverlapsToasts/,
  );
  assert.match(
    popup,
    /visible: frameAttached && toast\.attachmentProgress > 0\.001/,
  );
  assert.match(popup, /frameConnected: popup\.frameAttached/);
  assert.match(popup, /cornerRadius: toast\.cornerRadius/);
  assert.match(popup, /cornerRadius: popup\.theme\.radiusMedium/);
  assert.match(
    popup,
    /height: bottom - y,\s+cornerRadius: toast\.cornerRadius/,
  );
  assert.match(popup, /readonly property bool hubOverlapsToasts:/);
  assert.match(root, /hubBounds: expansionHost\.frameBounds/);
  assert.match(
    outputs,
    /hubVisible: outputs\.hubVisible && outputs\.hubScreen === screen/,
  );
  assert.match(popup, /glassAllowed: !popup\.hubOverlapsToasts/);
});

test("one notification server routes output-specific toast masks and frame docks", () => {
  const state = qml("NotificationState.qml");
  const root = qml("shell.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(state, /property string preferredOutput: ""/);
  assert.match(state, /outputName: preferredOutput/);
  assert.match(
    state,
    /ToastQueue\.layoutByOutput\(entries, outputCapacities, maxToasts/,
  );
  assert.match(state, /function moveOrphanedPopups/);
  assert.match(
    root,
    /preferredOutput: screens\.focusedScreen \? screens\.focusedScreen\.name/,
  );
  assert.match(root, /toastByOutput: notifications\.frameDocksByOutput/);
  assert.match(frame, /frame\.toastByOutput\[modelData\.name\]/);
  assert.match(qml("NotificationPopups.qml"), /model: Quickshell.screens/);
  assert.doesNotMatch(root, /NotificationPopup \{\s*id: notificationPopup/);
});

test("notifications announce sender, body, actions, and editable reply semantics", () => {
  const card = qml("NotificationCard.qml");
  const content = qml("NotificationContent.qml");
  const popup = qml("NotificationPopup.qml");
  const actions = qml("ShellAction.qml");
  assert.match(card, /Accessible\.role: Accessible\.ListItem/);
  assert.match(card, /Accessible\.name: \(notification/);
  assert.match(card, /Accessible\.description: \(notification/);
  assert.match(card, /Accessible\.role: Accessible\.EditableText/);
  assert.match(card, /Accessible\.name: "Reply to "/);
  assert.match(content, /Accessible\.description: groupItem\.expanded/);
  assert.match(popup, /Accessible\.role: Accessible\.AlertMessage/);
  assert.match(actions, /Accessible\.role: Accessible\.Button/);
  assert.match(actions, /Accessible\.name: title/);
});
