const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const host = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
  ),
  "utf8",
);

test("inactive prewarmed hub views cannot cover the active view's pointer region", () => {
  // Opacity alone does not remove a Qt Quick item from hit testing. Check
  // every retained page rather than only the Controls loader.
  for (let slot = 0; slot < 5; slot++) {
    assert.match(
      host,
      new RegExp(
        `id: contentLoader${"ABCDE"[slot]}[\\s\\S]*?enabled: host\\.activeSlot === ${slot}\\s+visible: host\\.activeSlot === ${slot} \\|\\| opacity > 0\\.01\\s+z: host\\.activeSlot === ${slot} \\? 1 : 0`,
      ),
    );
  }
  assert.match(host, /contentLoaderB\.sourceComponent = systemComponent/);
  assert.match(host, /contentLoaderA\.sourceComponent = calendarComponent/);
  assert.match(host, /contentLoaderD\.sourceComponent = mediaComponent/);
  assert.match(
    host,
    /duration: host\.activeSlot === 1 \? host\.motion\.contentFade : host\.motion\.effectsFast/,
  );
});
