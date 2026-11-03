const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (file) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", file),
    "utf8",
  );

test("compact bar islands receive reactive styling without independent connected borders", () => {
  const surface = qml("ShellSurface.qml");
  assert.match(surface, /property bool reactiveSurface: false/);
  assert.match(surface, /property bool frameConnected: false/);
  assert.match(surface, /musicActive:.*\(reactiveSurface \|\|/);
  assert.match(surface, /borderWidth: frameConnected \? 0 :/);
  assert.match(surface, /borderColor: frameConnected \? "transparent"/);
  const bar = qml("AmbientBar.qml");
  for (const island of [
    "workspaceIsland",
    "clockIsland",
    "notificationIsland",
    "recordingIsland",
  ]) {
    assert.match(
      bar,
      new RegExp(
        `ShellSurface \\{\\s*id: ${island}\\s*reactiveSurface: true\\s*frameConnected: bars\\.frameVisible`,
      ),
    );
  }
  for (const file of ["NowPlayingIsland.qml", "SystemIsland.qml"]) {
    assert.match(
      qml(file),
      /ShellSurface \{\s*anchors\.fill: parent\s*reactiveSurface: true\s*frameConnected: island\.frameConnected/,
    );
  }
});

test("reactive shell never increases existing outline weight", () => {
  const frame = qml("DesktopFrame.qml");
  assert.match(frame, /strokeColor: frame\.theme\.subtleBorder/);
  assert.match(frame, /strokeWidth: frame\.theme\.borderThin/);
  assert.doesNotMatch(frame, /reactiveBorder|strokeWidth:.*musicReactive/);
  const surface = qml("ShellSurface.qml");
  assert.match(surface, /borderWidth: frameConnected \? 0 : luminous \|\| outlined \? theme\.borderThin : 0/);
  assert.match(surface, /borderColor: frameConnected \? "transparent"/);
  assert.doesNotMatch(surface, /borderWidth:.*musicActive|borderColor:.*musicActive/);
  assert.match(surface, /return musicActive \? theme\.blend\(base, musicLight/);
  assert.match(surface, /lightColor: musicActive \? musicLight/);
});
