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
    /musicReactiveWash: musicReactiveEnabled \? Math\.min\(0\.18,/,
  );
  assert.match(
    theme,
    /const tinted = blend\(background, spectrumColor\(position\), strength\)/,
  );
  assert.match(
    theme,
    /reactiveFrameColor\(position: real, illuminated: bool\)/,
  );
  assert.match(theme, /shellGlassEnabled \? glassOpacity : 1/);
  assert.doesNotMatch(theme, /musicReactiveHue|musicReactiveBackground/);
  assert.match(frame, /fillGradient: LinearGradient \{/);
  assert.match(frame, /x1: 0/);
  assert.match(frame, /x2: drawing\.width/);
  for (const point of [
    "0",
    "0.125",
    "0.25",
    "0.375",
    "0.5",
    "0.625",
    "0.75",
    "0.875",
    "1",
  ])
    assert.ok(
      frame.includes(
        "reactiveFrameColor(" + point + ", output.reactiveActive)",
      ),
    );
  assert.match(
    theme,
    /reactiveFrameColor\(position: real, illuminated: bool\)/,
  );
  assert.match(theme, /const harmonic =/);
  assert.match(
    theme,
    /const impulse = Math\.max\(0, Math\.min\(1, musicReactiveImpulses\[index\] \|\| 0\)\)/,
  );
  assert.match(theme, /const strength = Math\.max\(0, Math\.min\(0\.94,/);
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
    /float position = std::clamp\(float\(point\.x\(\)\) \/ w, 0\.0f, 1\.0f\)/,
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

test("reactive audio retains one event-driven pipeline and independently detects kicks", () => {
  const reactive = qml("MusicReactiveState.qml");
  const analyser = qml("ReactiveAudio.js");
  const spectrum = qml("SpectrumState.qml");
  assert.match(reactive, /import "ReactiveAudio\.js" as ReactiveAudio/);
  assert.match(
    reactive,
    /function onSequenceChanged\(\): void \{\s*reactive\.updateAudio\(\)/,
  );
  assert.match(reactive, /ReactiveAudio\.advanceAudio\(reactive,/);
  assert.match(analyser, /hz >= 60 && hz < 250/);
  assert.match(analyser, /hz >= 250 && hz < 2100/);
  assert.match(analyser, /state\.sinceKick >= 0\.11/);
  assert.match(analyser, /state\.motionAmount = clamp/);
  assert.match(
    spectrum,
    /spectrum\.updateBands\(frame\.bands\);\s*spectrum\.sequence = frame\.seq/,
  );
});

test("silence decays and disconnect releases before resetting every reactive field", () => {
  const reactive = qml("MusicReactiveState.qml");
  for (const value of [
    "sustain",
    "beatPulse",
    "treble",
    "kick",
    "body",
    "presence",
    "motionAmount",
  ])
    assert.match(reactive, new RegExp(value + " = 0;"));
  assert.match(reactive, /running: reactive\.releasing && reactive\.enabled/);
  assert.match(reactive, /interval: 16/);
  assert.match(
    reactive,
    /Math\.max\(\.\.\.reactive\.spectrumLevels, \.\.\.reactive\.impulseLevels\) < 0\.001/,
  );
  assert.match(
    reactive,
    /onConnectedChanged\(\): void \{\s*if \(\(!reactive\.spectrum \|\| !reactive\.spectrum\.connected\) && reactive\.enabled\)\s*reactive\.releasing = true/,
  );
});

test("closed hub and hidden bar still keep the visible frame reactive", () => {
  const root = qml("shell.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(
    root,
    /musicReactiveSurfaceVisible: musicReactiveEnabled && \(desktopFrame\.glassExposed \|\| ambientBar\.shown/,
  );
  assert.match(frame, /glassExposed: enabled && Quickshell\.screens\.some/);
  assert.match(root, /active: .*root\.musicReactiveSurfaceVisible/);
  assert.match(root, /enabled: root\.musicReactiveSurfaceVisible/);
  assert.match(root, /musicReactiveBands: reactive\.spectrumLevels/);
  assert.match(root, /musicReactiveBandLevels\(\): string/);
  for (const current of [
    { frame: true, bar: false, hub: false, expected: true },
    { frame: true, bar: true, hub: false, expected: true },
    { frame: false, bar: true, hub: false, expected: true },
    { frame: false, bar: false, hub: true, expected: true },
    { frame: false, bar: false, hub: false, expected: false },
  ])
    assert.equal(current.frame || current.bar || current.hub, current.expected);
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

test("native squircle receives the same live FFT zones without an independent animation phase", () => {
  const root = qml("shell.qml");
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  const squircle = qml("SquircleSurface.qml");
  const surface = qml("ShellSurface.qml");
  assert.match(native, /QVariantList gradientBands MEMBER gradientBands_/);
  assert.match(
    native,
    /QVariantList gradientImpulses MEMBER gradientImpulses_/,
  );
  assert.match(root, /musicReactiveImpulses: reactive\.impulseLevels/);
  assert.match(native, /NOTIFY gradientMotionChanged/);
  assert.match(native, /const float bandPosition = position \* 8/);
  assert.match(native, /const float level = levels\[size_t\(leftBand\)\]/);
  assert.match(native, /const float localStrength =/);
  assert.doesNotMatch(
    native,
    /gradientPhase|std::sin\(gradientPhase|class FrameRibbonItem|class FrameFillItem/,
  );
  assert.match(squircle, /gradientBands: root\.reactiveGradientBands/);
  assert.match(
    surface,
    /reactiveGradientBands: musicActive \? theme\.musicReactiveBands : \[\]/,
  );
  for (const name of ["Movement", "Kick"]) {
    assert.match(
      squircle,
      new RegExp("gradient" + name + ": root.reactiveGradient" + name),
    );
    assert.match(
      surface,
      new RegExp(
        "reactiveGradient" +
          name +
          ": musicActive \\? theme.musicReactive" +
          name,
      ),
    );
  }
});

test("connected frame animates only its own clipped fill and never draws separate geometry over windows", () => {
  const frame = qml("DesktopFrame.qml");
  const renderer = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(frame, /fillRule: Qt\.OddEvenFill/);
  assert.match(frame, /path: output\.geometry\.fill/);
  assert.match(frame, /reactiveFrameColor\(0\.5, output\.reactiveActive\)/);
  assert.match(frame, /strokeColor: frame\.reactiveBorder/);
  assert.doesNotMatch(
    frame,
    /FrameRibbonItem|FrameFillItem|contourPoints: output\.geometry\.renderPoints/,
  );
  assert.doesNotMatch(renderer, /class FrameRibbonItem|class FrameFillItem/);
  assert.match(frame, /x1: 0[\s\S]*?x2: drawing\.width/);
  assert.doesNotMatch(frame, /Math\.sin\(frame\.theme\.musicReactiveFlow\)/);
});

test("spectrum-driven rendering ignores the UI motion preference", () => {
  const root = qml("shell.qml");
  const surface = qml("ShellSurface.qml");
  const frame = qml("DesktopFrame.qml");
  assert.match(root, /musicReactiveBands: reactive\.spectrumLevels/);
  assert.match(
    surface,
    /reactiveGradientBands: musicActive \? theme\.musicReactiveBands : \[\]/,
  );
  for (const [name, binding] of [
    ["Movement", "motionAmount"],
    ["Kick", "kick"],
  ]) {
    assert.match(
      root,
      new RegExp("musicReactive" + name + ": reactive\\." + binding),
    );
    assert.doesNotMatch(
      root,
      new RegExp("musicReactive" + name + ": motion\\.enabled"),
    );
  }
  assert.doesNotMatch(
    frame,
    /output\.reactiveActive && frame\.motion\.enabled/,
  );
  assert.match(frame, /reactiveFrameColor\(0\.5, output\.reactiveActive\)/);
  assert.doesNotMatch(frame, /FrameRibbonItem|FrameFillItem/);
  // Motion preference still gates UI tween durations, not DSP movement.
  assert.match(
    qml("Motion.qml"),
    /readonly property int morph: enabled \? 240 : 0/,
  );
});
