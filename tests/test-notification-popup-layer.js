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
    root.indexOf("ShellExpansionHost {") < root.indexOf("NotificationPopup {"),
  );
  assert.match(popup, /WlrLayershell\.layer: WlrLayer\.Overlay/);
  assert.match(
    popup,
    /WlrLayershell\.namespace: "linux-desktop-notification-popup"/,
  );
  assert.match(popup, /mask: surfaceLifecycle\.inputRegion/);
  assert.match(popup, /interactiveItem: toastInputArea/);
  assert.match(popup, /readonly property int maxToastSlots:/);
  assert.match(
    root,
    /hubVisible: \(expansionState\.hasCurrent \|\| expansionHost\.closing\) && expansionHost\.screen === screen/,
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
  assert.match(popup, /glassAllowed: !popup\.hubOverlapsToasts/);
});
