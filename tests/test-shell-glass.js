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
  assert.match(frame, /fillGradient: LinearGradient \{/);
  assert.match(frame, /reactiveFrameColor\(0\.5\)/);
  assert.match(qml("Theme.qml"), /shellGlassEnabled \? glassOpacity : 1/);
  assert.match(shell, /frameGlassExposed: desktopFrame\.glassExposed/);
  assert.match(shell, /DesktopFrame \{\s*id: desktopFrame/);
  assert.match(preferences, /property bool frameGlassExposed: false/);
  assert.match(
    preferences,
    /applyGlassRule\("desktop-shell-shell-glass-frame", "\^desktop-shell-frame\$", frameGlassExposed\)/,
  );
  // Connected bar islands borrow frame glass; detached islands retain blur.
  assert.match(
    preferences,
    /readonly property bool barGlassExposed: barVisible && !frameGlassExposed/,
  );
  assert.match(
    preferences,
    /applyGlassRule\("desktop-shell-shell-glass", "\^desktop-shell-bar\$", barGlassExposed\)/,
  );
  assert.match(preferences, /onBarGlassExposedChanged: applyGlassRule/);
});

test("connected hub borrows a single glass material from the shared contour", () => {
  const hub = qml("ShellExpansionHost.qml");
  const surface = qml("ShellSurface.qml");
  assert.match(hub, /fillColor: host\.theme\.background/);
  assert.match(hub, /frameConnected: host\.frameVisible/);
  assert.doesNotMatch(hub, /glassAllowed: !host\.frameVisible/);
  assert.match(surface, /fillOpacity: frameConnected \? 0 : !glassAllowed/);
  assert.match(
    surface,
    /fillOpacity: frameConnected \? 0 : !glassAllowed[^\n]*: theme\.glassOpacity/,
  );
  assert.match(
    qml("AppearancePreferences.qml"),
    /applyGlassRule\("desktop-shell-shell-glass-expansion", "\^desktop-shell-expansion\$", expansionGlassExposed\)/,
  );
  assert.match(
    qml("shell.qml"),
    /expansionGlassExposed: \(qmlExpansionState\.hasCurrent \|\| expansionHost\.closing\) && !expansionHost\.frameVisible/,
  );
});

test("connected popups borrow the frame material, while overlapping toasts use their own backing", () => {
  for (const [file, owner, base] of [
    ["OsdPopup.qml", "qmlPopup", "groupBase"],
    ["ResizeOverlay.qml", "overlay", "panelBase"],
  ]) {
    const src = qml(file);
    assert.match(src, new RegExp(`frameConnected: ${owner}\\.frameConnected`));
    assert.ok(src.includes(`fillColor: ${owner}.theme.${base}`));
    assert.doesNotMatch(src, /glassAllowed: !.*frameConnected/);
  }
  const toasts = qml("NotificationPopup.qml");
  assert.match(toasts, /frameConnected: qmlPopup\.frameAttached/);
  assert.match(
    toasts,
    /readonly property bool frameAttached: frameConnected && !hubOverlapsToasts/,
  );
  assert.match(toasts, /glassAllowed: !qmlPopup\.hubOverlapsToasts/);
  assert.match(toasts, /fillColor: qmlPopup\.theme\.paneBase/);
  const prefs = qml("AppearancePreferences.qml");
  const shell = qml("shell.qml");
  assert.match(
    prefs,
    /applyGlassRule\("desktop-shell-shell-glass-resize", "\^desktop-shell-resize-controls\$", resizeGlassExposed\)/,
  );
  assert.match(
    shell,
    /resizeGlassExposed: resizeOverlay\.open \|\| resizeOverlay\.closing/,
  );
});

// The frame already contains all attached top, side and bottom notch wells;
// compositing another translucent pane would reduce transmission to (1-a)^2.
test("connected panes do not double-tint the frame, but detached glass still works", () => {
  const surface = qml("ShellSurface.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(surface, /fillOpacity: frameConnected \? 0 : !glassAllowed/);
  assert.match(
    surface,
    /fillOpacity: frameConnected \? 0 : !glassAllowed[^\n]*: theme\.glassOpacity/,
  );
  assert.match(host, /frameConnected: host\.frameVisible/);
  assert.match(surface, /Behavior on fillOpacity/);
  assert.doesNotMatch(
    surface,
    /fillOpacity: frameConnected && !theme\.shellGlassEnabled/,
  );
  for (const file of [
    "NotificationPopup.qml",
    "OsdPopup.qml",
    "ResizeOverlay.qml",
  ])
    assert.doesNotMatch(
      qml(file),
      /frameConnected && !.*shellGlassEnabled \? "transparent"/,
    );
});

test("Help feather mask fades all four edges and multiplies their corner alpha", () => {
  const host = qml("ShellExpansionHost.qml");
  const mask = qml("EdgeFeatherMask.qml");
  assert.match(
    host,
    /EdgeFeatherMask \{\s*id: helpBlurMask\s*anchors\.fill: contentViewport\s*active: scopedHelp\.visible && host\.theme\.shellGlassEnabled/,
  );
  assert.match(host, /maskEnabled: true[\s\S]*?maskSource: helpBlurMask/);
  assert.match(mask, /property real feather: 40/);
  assert.match(mask, /layer\.enabled: active/);
  assert.match(mask, /globalCompositeOperation = "destination-in"/);
  assert.match(mask, /if \(active && available\)\s*requestPaint\(\)/);

  const { gradientStops } = require("node:vm").runInNewContext(
    qml("EdgeFeather.js") + "\n({ gradientStops })",
  );
  for (const extent of [24, 80, 128, 720, 1600]) {
    const stops = gradientStops(extent, 40);
    assert.equal(stops[0][0], 0);
    assert.equal(stops[0][1], 0);
    assert.equal(stops.at(-1)[0], 1);
    assert.equal(stops.at(-1)[1], 0);
    assert.ok(
      stops.every(
        ([x, a], i) =>
          x >= 0 && x <= 1 && a >= 0 && a <= 1 && (!i || x > stops[i - 1][0]),
      ),
    );
    const fraction = Math.min(0.5, 40 / extent);
    assert.ok(
      stops.some(([x, a]) => Math.abs(x - fraction / 2) < 1e-9 && a === 0.5),
    );
    assert.ok(stops.some(([x, a]) => Math.abs(x - fraction) < 1e-9 && a === 1));
    const sideAlpha = stops.find(([x]) => Math.abs(x - fraction / 2) < 1e-9)[1];
    assert.equal(sideAlpha * sideAlpha, 0.25);
  }
});

test("hub Help blurs the original content viewport without a copied backdrop", () => {
  const host = qml("ShellExpansionHost.qml");
  const help = qml("WidgetHelp.qml");
  assert.match(host, /import QtQuick\.Effects/);
  assert.match(
    host,
    /layer\.enabled: scopedHelp\.visible && host\.theme\.shellGlassEnabled/,
  );
  assert.match(host, /layer\.effect: MultiEffect \{[\s\S]*?blurEnabled: true/);
  assert.match(host, /autoPaddingEnabled: false/);
  assert.match(host, /contentArea: contentViewport/);
  assert.match(help, /property Item contentArea: null/);
  assert.match(help, /help\.theme\.shellGlassEnabled \? 0\.36 : 0\.70/);
  assert.match(help, /fillColor: Qt\.rgba\(help\.theme\.background\.r/);
  assert.doesNotMatch(
    help,
    /ShaderEffectSource|MultiEffect|hideSource|blurSource|maskSource/,
  );
  assert.match(host, /HubTabs \{[\s\S]*?z: 250/);
  assert.doesNotMatch(help, /PanelWindow/);
});
