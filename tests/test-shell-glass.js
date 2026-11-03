const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("frosted glass blurs the active connected frame as one visible layer", () => {
  const frame = qml("DesktopFrame.qml");
  const shell = qml("shell.qml");
  const preferences = qml("AppearancePreferences.qml");
  assert.match(frame, /glassExposed: enabled && Quickshell\.screens\.some\(/);
  assert.match(
    frame,
    /fillColor: Qt\.rgba\(frame\.theme\.musicReactiveBackground\.r,[^\n]+frame\.theme\.shellGlassEnabled \? frame\.theme\.glassOpacity : 1\)/,
  );
  assert.match(shell, /frameGlassExposed: desktopFrame\.glassExposed/);
  assert.match(shell, /DesktopFrame \{\s*id: desktopFrame/);
  assert.match(preferences, /property bool frameGlassExposed: false/);
  assert.match(
    preferences,
    /applyGlassRule\("linux-desktop-shell-glass-frame", "\^linux-desktop-frame\$", frameGlassExposed\)/,
  );
  // Bar islands and the shared contour live in different Wayland layers.
  // Both require conditional blur for the complete connected glass surface.
  assert.match(
    preferences,
    /applyGlassRule\("linux-desktop-shell-glass", "\^linux-desktop-bar\$", barVisible\)/,
  );
});

test("the connected hub keeps the same glass fill without an opaque override", () => {
  const hub = qml("ShellExpansionHost.qml");
  const surface = qml("ShellSurface.qml");
  assert.match(hub, /fillColor: host\.theme\.musicReactiveBackground/);
  assert.doesNotMatch(hub, /glassAllowed: !host\.frameVisible/);
  assert.match(
    surface,
    /fillOpacity: frameConnected && !theme\.shellGlassEnabled \? theme\.musicReactiveWash/,
  );
  assert.match(
    surface,
    /surfaceLayer === ShellSurface\.Pane \? theme\.glassOpacity/,
  );
  assert.match(
    qml("AppearancePreferences.qml"),
    /applyGlassRule\("linux-desktop-shell-glass-expansion", "\^linux-desktop-expansion\$", expansionGlassExposed\)/,
  );
});

test("all connected popups keep glass available in both frame modes", () => {
  for (const [file, owner, base] of [
    ["NotificationPopup.qml", "popup", "paneBase"],
    ["OsdPopup.qml", "popup", "groupBase"],
    ["ResizeOverlay.qml", "overlay", "panelBase"],
  ]) {
    const src = qml(file);
    assert.match(src, new RegExp(`frameConnected: ${owner}\\.frameConnected`));
    assert.ok(
      src.includes(
        `fillColor: ${owner}.frameConnected && !${owner}.theme.shellGlassEnabled ? "transparent" : ${owner}.theme.${base}`,
      ),
    );
    assert.doesNotMatch(src, /glassAllowed: !.*frameConnected/);
  }
  const prefs = qml("AppearancePreferences.qml");
  const shell = qml("shell.qml");
  assert.match(
    prefs,
    /applyGlassRule\("linux-desktop-shell-glass-resize", "\^linux-desktop-resize-controls\$", resizeGlassExposed\)/,
  );
  assert.match(
    shell,
    /resizeGlassExposed: resizeOverlay\.open \|\| resizeOverlay\.closing/,
  );
});
