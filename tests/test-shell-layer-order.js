const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "../modules/desktop/hyprland/shell");
const source = fs.readFileSync(path.join(root, "default.nix"), "utf8");
const rules = source.match(
  /wayland\.windowManager\.hyprland\.settings\.config\.layer_rule = \[([\s\S]*?)\];/,
)[1];
const order = Object.fromEntries(
  [...rules.matchAll(/match\.namespace = "\^desktop-shell-([a-z-]+)\$";\s*order = (-?\d+);/g)].map(
    ([, name, value]) => [name, Number(value)],
  ),
);

test("interactive shell layers have stable compositor hit-test priority over ordinary overlays", () => {
  assert.ok(order.expansion < 0);
  for (const [file, namespace] of [
    ["ShellExpansionHost.qml", "expansion"],
    ["NotificationPopup.qml", "notification-popup"],
    ["ModalSurfaceHost.qml", "modal"],
    ["shell.qml", "capture"],
    ["PolkitDialog.qml", "authentication"],
  ]) {
    const qml = fs.readFileSync(path.join(root, "qml", file), "utf8");
    assert.ok(qml.includes('WlrLayershell.namespace: "desktop-shell-' + namespace + '"'));
    assert.ok(order[namespace] < 0, namespace);
  }
  // The compositor sorts descending and hit-tests in reverse. The default
  // order of other overlay clients is zero, independent of their map time.
  assert.deepEqual(
    Object.entries(order).sort((a, b) => a[1] - b[1]).map(([name]) => name),
    ["authentication", "capture", "modal", "notification-popup", "expansion"],
  );
});

test("the hub continues to use the native input mask and focus grab", () => {
  const hub = fs.readFileSync(path.join(root, "qml/ShellExpansionHost.qml"), "utf8");
  const lifecycle = fs.readFileSync(path.join(root, "qml/PopupSurfaceLifecycle.qml"), "utf8");
  assert.match(hub, /mask: surfaceLifecycle\.inputRegion/);
  assert.match(hub, /interactiveItem: shellSurface/);
  assert.match(hub, /HyprlandFocusGrab\s*\{/);
  assert.match(lifecycle, /item: lifecycle\.exposed \? lifecycle\.interactiveItem : lifecycle/);
});
