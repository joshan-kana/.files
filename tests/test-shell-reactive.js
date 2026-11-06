const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (file) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", file),
    "utf8",
  );

test("native squircle fill retains outlines while reusing premultiplied scene-graph geometry", () => {
  const surface = qml("SquircleSurface.qml");
  const renderer = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );

  assert.match(surface, /import LinuxDesktop\.Visuals 1\.0/);
  assert.match(surface, /SquircleFillItem\s*\{/);
  assert.match(surface, /lightStrength: root\.lightStrength/);
  assert.match(surface, /PathSvg\s*\{\s*path: root\.borderPathData/);
  assert.match(surface, /path: root\.fillPathData/);
  assert.doesNotMatch(surface, /fillGradient: RadialGradient/);

  assert.match(renderer, /class SquircleFillItem : public QQuickItem/);
  assert.match(renderer, /QSGGeometryNode/);
  assert.match(renderer, /geometry->vertexCount\(\) != triangles \* 3/);
  assert.match(renderer, /qPremultiply\(color\.rgba\(\)\)/);
  assert.match(renderer, /baseAlpha <= 0\.00001f && lightAlpha <= 0\.00001f/);
});

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
        `ShellSurface \\{\\s*id: ${island}[\\s\\S]*?reactiveSurface: true\\s*frameConnected: bars\\.frameVisible`,
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

test("the reactive shell shares the spectrum's three-stop red-blue-cyan palette", () => {
  const theme = qml("Theme.qml");
  const frame = qml("DesktopFrame.qml");
  const surface = qml("ShellSurface.qml");
  const squircle = qml("SquircleSurface.qml");
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(theme, /const stops = \[critical, accent, accentTertiary\]/);
  assert.match(
    theme,
    /musicReactiveWash: musicReactiveEnabled \? Math\.min\(0\.42,/,
  );
  assert.match(
    theme,
    /return musicReactiveWash > 0 \? blend\(base, spectrumColor\(position\), musicReactiveWash\) : base/,
  );
  assert.match(theme, /reactiveFrameColor\(position: real\)/);
  assert.match(theme, /shellGlassEnabled \? glassOpacity : 1/);
  assert.doesNotMatch(theme, /musicReactiveHue|musicReactiveBackground/);
  assert.match(frame, /fillGradient: LinearGradient \{/);
  assert.match(frame, /x2: drawing\.width/);
  assert.match(frame, /gradientInset: Math\.max\(0\.005,/);
  assert.match(frame, /position: output\.gradientInset/);
  assert.match(frame, /position: 1 - output\.gradientInset/);
  for (const point of ["0", "0.5", "1"])
    assert.ok(frame.includes("reactiveFrameColor(" + point + ")"));
  assert.match(frame, /strokeColor: frame\.reactiveBorder/);
  assert.match(frame, /strokeWidth: frame\.theme\.borderThin/);
  assert.match(
    surface,
    /reactiveGradientStrength: musicActive \? theme\.musicReactiveWash : 0/,
  );
  for (const [property, point] of [
    ["Low", "0"],
    ["Mid", "0.5"],
    ["High", "1"],
  ])
    assert.ok(
      surface.includes(
        "reactiveGradient" + property + ": theme.spectrumColor(" + point + ")",
      ),
    );
  assert.match(squircle, /gradientStrength: root\.reactiveGradientStrength/);
  assert.match(
    native,
    /double gradientStrength MEMBER gradientStrength_ NOTIFY gradientChanged/,
  );
  assert.match(
    native,
    /const float position = std::clamp\(float\(point\.x\(\)\) \/ w, 0\.0f, 1\.0f\)/,
  );
  assert.match(native, /qPremultiply\(color\.rgba\(\)\)/);
  for (const file of [
    "NowPlayingIsland.qml",
    "SystemIsland.qml",
    "ShellExpansionHost.qml",
    "AmbientBar.qml",
  ])
    assert.doesNotMatch(qml(file), /musicReactiveBackground/);
});

test("silent reactive surfaces retain the original fill, glass and outline", () => {
  const surface = qml("ShellSurface.qml");
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(
    surface,
    /reactiveGradientStrength: musicActive \? theme\.musicReactiveWash : 0/,
  );
  assert.match(surface, /return base;/);
  assert.match(surface, /lightColor: luminousColor/);
  assert.match(surface, /lightStrength: luminous \?/);
  assert.match(
    surface,
    /borderWidth: frameConnected \? 0 : luminous \|\| outlined \? theme\.borderThin : 0/,
  );
  assert.match(surface, /borderColor: frameConnected \? "transparent"/);
  assert.doesNotMatch(surface, /musicGlow|lightSpread: musicActive|musicLight/);
  assert.doesNotMatch(
    surface,
    /borderWidth:.*musicActive|borderColor:.*musicActive/,
  );
  assert.match(native, /if \(gradientStrength > 0\.00001f\)/);
  assert.match(native, /baseRed \+=/);
  assert.match(native, /gradientStrength_ = 0/);
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
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(native, /const QPointF lightCenter\(w \* 0\.15, h \* -0\.16\)/);
  assert.match(
    native,
    /std::max\(w \* 0\.9f, h \* 2\.0f\) \* float\(lightSpread_\)/,
  );
  assert.doesNotMatch(surface, /musicGlow|lightSpread: musicActive/);
});
