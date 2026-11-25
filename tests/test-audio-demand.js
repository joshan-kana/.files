const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shell = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/qml/shell.qml"),
  "utf8",
);

test("reactive styling is driven by observed shell surfaces, not a saved toggle alone", () => {
  assert.match(
    shell,
    /readonly property bool musicReactiveSurfaceVisible: musicReactiveEnabled && \(/,
  );
  for (const surface of [
    "desktopFrame.glassExposed",
    "qmlAmbientBar.shown",
    "qmlExpansionState.hasCurrent",
    "expansionHost.closing",
    "modalHost.contentVisible",
    "qmlNotifications.popupVisible",
    "qmlOsd.visible",
    "osdPopup.closing",
    "resizeOverlay.open",
    "resizeOverlay.closing",
  ]) {
    assert.ok(
      shell.includes(surface),
      `${surface} must count as a live reactive consumer`,
    );
  }
  assert.match(
    shell,
    /musicReactiveEnabled: root\.musicReactiveSurfaceVisible/,
  );
  assert.match(shell, /enabled: root\.musicReactiveSurfaceVisible/);
});

test("FFT remains active for visible media and wallpaper even when reactive styling is sleeping", () => {
  assert.match(shell, /active: visualizerSubscribers > 0/);
  assert.match(
    shell,
    /\|\| root\.wallpaperSpectrumEnabled \|\| root\.musicReactiveSurfaceVisible/,
  );
  assert.match(
    shell,
    /readonly property bool musicReactiveEnabled: qmlAppearance\.musicReactiveEnabled/,
  );
});

test("paused media does not retain an analyser subscription just to render its decay", () => {
  for (const [name, owner] of [
    ["ControlsMediaCard", "card"],
    ["MediaContent", "content"],
  ]) {
    const source = fs.readFileSync(
      path.join(
        __dirname,
        "../modules/desktop/hyprland/shell/qml",
        name + ".qml",
      ),
      "utf8",
    );
    assert.ok(source.includes("drivesDemand: " + owner + ".media.playing"));
  }
});
