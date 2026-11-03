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

test("one acoustic wash paints connected frame, hub and independent islands", () => {
  const theme = qml("Theme.qml");
  assert.match(
    theme,
    /musicReactiveWash: musicReactiveEnabled \? Math\.min\(0\.13,/,
  );
  assert.match(
    theme,
    /musicReactiveBackground: musicReactiveWash > 0 \? blend\(background, musicReactiveHue, musicReactiveWash\) : background/,
  );
  const frame = qml("DesktopFrame.qml");
  assert.match(
    frame,
    /fillColor: Qt\.rgba\(frame\.theme\.musicReactiveBackground\.r,/,
  );
  assert.match(frame, /strokeColor: frame\.reactiveBorder/);
  assert.match(frame, /strokeWidth: frame\.theme\.borderThin/);
  assert.match(frame, /reactiveTint: theme\.musicReactiveWash > 0/);
  assert.match(
    frame,
    /reactiveBorder: Qt\.rgba\(reactiveTint\.r, reactiveTint\.g, reactiveTint\.b, theme\.subtleBorder\.a\)/,
  );
  assert.match(
    qml("ShellExpansionHost.qml"),
    /fillColor: host\.theme\.musicReactiveBackground/,
  );
  for (const file of ["NowPlayingIsland.qml", "SystemIsland.qml"]) {
    assert.match(qml(file), /fillColor: theme\.musicReactiveBackground/);
  }
  // The four other bar islands supply their own background, so all must
  // consume the shared wash instead of falling back to the static
  // theme background. Shared frame mode owns the outline, not the fill.
  const bar = qml("AmbientBar.qml");
  const fills = bar.match(/fillColor: theme\.musicReactiveBackground/g) || [];
  assert.equal(fills.length, 4);
  assert.doesNotMatch(
    bar,
    /fillColor: bars\.frameVisible \? "transparent" : theme\.background/,
  );
});

test("silent reactive surfaces are the original unraised connected silhouettes", () => {
  const source = qml("ShellSurface.qml");
  assert.match(
    source,
    /return frameConnected \? "transparent" : musicActive && theme\.musicReactiveWash > 0/,
  );
  assert.match(source, /lightColor: luminousColor/);
  assert.match(source, /lightStrength: luminous \?/);
  assert.doesNotMatch(source, /musicGlow|lightSpread: musicActive|musicLight/);
  assert.match(
    source,
    /borderWidth: frameConnected \? 0 : luminous \|\| outlined \? theme\.borderThin : 0/,
  );
  assert.match(source, /borderColor: frameConnected \? "transparent"/);
  assert.doesNotMatch(
    source,
    /borderWidth:.*musicActive|borderColor:.*musicActive/,
  );
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
  assert.match(reactive, /sustain = presence \* clamp\(/);
  assert.match(reactive, /treble = presence \* clamp\(/);
  assert.match(reactive, /elapsed \* 15/);
});

test("reactive audio returns to exact zero on silence and connection loss", () => {
  const reactive = qml("MusicReactiveState.qml");
  assert.match(
    reactive,
    /loudness = Math\.max\(spectrum\.rms, spectrum\.peak \* 0\.35\)/,
  );
  assert.match(reactive, /!spectrum\.connected \|\| loudness <= 0\.003/);
  assert.match(
    reactive,
    /const presence = clamp\(\(loudness - 0\.003\) \/ 0\.025\)/,
  );
  for (const field of ["sustain", "beatPulse", "treble"])
    assert.match(reactive, new RegExp(`${field} = presence \\*`));
  assert.match(
    reactive,
    /onConnectedChanged\(\): void \{\s*if \(\!reactive\.spectrum\.connected\)\s*reactive\.reset\(\)/,
  );
});

test("surface curves remain cubic, and only ordinary hover may use a radial light", () => {
  const curve = qml("SquircleSurface.qml");
  const surface = qml("ShellSurface.qml");
  assert.match(curve, /function buildCorner\([\s\S]*?return " C " \+/);
  assert.doesNotMatch(curve, /cornerSamples/);
  assert.match(curve, /centerRadius: .*root\.lightSpread/);
  assert.doesNotMatch(surface, /musicGlow|lightSpread: musicActive/);
});
