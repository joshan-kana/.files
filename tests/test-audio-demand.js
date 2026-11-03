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
    "ambientBar.shown",
    "expansionState.hasCurrent",
    "expansionHost.closing",
    "modalHost.contentVisible",
    "notifications.popupVisible",
    "osd.visible",
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
    /musicReactiveEnabled: root\.musicReactiveSurfaceVisible && motion\.enabled/,
  );
  assert.match(
    shell,
    /enabled: root\.musicReactiveSurfaceVisible && motion\.enabled/,
  );
});

test("FFT remains active for visible media and wallpaper even when reactive styling is sleeping", () => {
  assert.match(shell, /active: \(media\.playing && ambientBar\.shown\)/);
  assert.match(
    shell,
    /\|\| root\.wallpaperSpectrumEnabled \|\| \(motion\.enabled && root\.musicReactiveSurfaceVisible\)/,
  );
  assert.match(
    shell,
    /readonly property bool musicReactiveEnabled: appearance\.musicReactiveEnabled/,
  );
});
