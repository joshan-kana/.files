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
  assert.match(
    surface,
    /borderWidth: frameConnected \? 0 : luminous \|\| outlined \? theme\.borderThin : 0/,
  );
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

test("reactive shell keeps all existing outline widths and colours unchanged", () => {
  const frame = qml("DesktopFrame.qml");
  assert.match(frame, /strokeColor: frame\.reactiveBorder/);
  assert.match(frame, /strokeWidth: frame\.theme\.borderThin/);
  assert.match(
    frame,
    /reactiveTint: theme\.musicReactiveEnabled && motion\.enabled/,
  );
  assert.match(
    frame,
    /reactiveBorder: Qt\.rgba\(reactiveTint\.r, reactiveTint\.g, reactiveTint\.b, theme\.subtleBorder\.a\)/,
  );
  assert.doesNotMatch(frame, /strokeWidth:.*musicReactive/);
  const surface = qml("ShellSurface.qml");
  assert.match(
    surface,
    /borderWidth: frameConnected \? 0 : luminous \|\| outlined \? theme\.borderThin : 0/,
  );
  assert.match(surface, /borderColor: frameConnected \? "transparent"/);
  assert.doesNotMatch(
    surface,
    /borderWidth:.*musicActive|borderColor:.*musicActive/,
  );
  assert.match(surface, /return musicActive \? theme\.blend\(base, musicLight/);
  assert.match(surface, /lightColor: musicActive \? musicLight/);
});

test("reactive audio uses continuous event-driven values instead of quantized brightness bands", () => {
  const reactive = qml("MusicReactiveState.qml");
  assert.doesNotMatch(
    reactive,
    /function quantize|Math\.round\(clamp\(value\) \* 12\)|lastUpdateMs < 66/,
  );
  assert.match(
    reactive,
    /function onSequenceChanged\(\): void \{\s*reactive\.updateAudio\(\)/,
  );
  assert.match(reactive, /sustain = clamp\(/);
  assert.match(reactive, /treble = clamp\(/);
  assert.match(reactive, /elapsed \* 15/);
});

test("music-lit superellipses use smooth cubic contours and a bounded glow", () => {
  const curve = qml("SquircleSurface.qml");
  const surface = qml("ShellSurface.qml");
  assert.match(curve, /function buildCorner\([\s\S]*?return " C " \+/);
  assert.doesNotMatch(curve, /cornerSamples/);
  assert.match(curve, /centerRadius: .*root\.lightSpread/);
  assert.match(surface, /musicGlow: Math\.min\(0\.30,/);
  assert.match(surface, /lightSpread: musicActive \? 0\.62 : 1/);
});
