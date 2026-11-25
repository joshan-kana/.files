const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("now-playing visualizer remains rendered below the lyrics overlay in both modes", () => {
  const media = qml("MediaContent.qml");
  const visualizer = qml("SpectrumVisualizer.qml");
  assert.match(visualizer, /root.mode === "curve" \|\| opacity > 0\.01/);
  assert.match(visualizer, /root.mode === "bars" \|\| opacity > 0\.01/);
  assert.ok(
    media.indexOf("SpectrumVisualizer {") < media.indexOf("MediaLyrics {"),
  );
  assert.match(media, /active: content\.engaged && content\.lyricsVisible/);
  assert.match(media, /opacity: content\.lyricsVisible \? 1 : 0/);
});

test("lyric changes scroll into the centre with the shared motion preference", () => {
  const lyrics = qml("MediaLyrics.qml");
  assert.match(lyrics, /currentIndex: root\.currentLine/);
  assert.match(lyrics, /highlightRangeMode: ListView\.StrictlyEnforceRange/);
  assert.match(lyrics, /highlightMoveDuration: root\.motion\.spatialNormal/);
  assert.match(lyrics, /highlightMoveVelocity: -1/);
  assert.match(lyrics, /Behavior on opacity \{/);
  assert.match(lyrics, /Behavior on scale \{/);
  assert.match(lyrics, /interactive: false/);
  assert.match(lyrics, /Lyrics\.currentIndex\(lines, media\.position\)/);
  assert.match(lyrics, /root\.media\.lyricsPath/);
});

test("native curve outline and fill share the same sampled theme colours as bars", () => {
  const renderer = qml("SpectrumRenderer.qml");
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(
    renderer,
    /theme.spectrumColor\(curve \? i \/ Math.max\(1, count - 1\) : \(i \+ 0.5\) \/ count\)/,
  );
  assert.match(native, /void renderCurve\(QSGGeometryNode \*node, int count\)/);
  assert.match(native, /strip\(fillA, fillB, h, h, 0.12f, 0.12f\)/);
  assert.match(
    native,
    /strip\(previous, point, fillA.y\(\), fillB.y\(\), 1, 1\)/,
  );
  assert.match(native, /qPremultiply\(color.rgba\(\)\)/);
});

test("lyrics omit redundant local status labels while preserving frequency markers", () => {
  const media = qml("MediaContent.qml");
  const lyrics = qml("MediaLyrics.qml");
  assert.doesNotMatch(media, /id: lyricsFooter|LOCAL FILES ONLY/);
  assert.doesNotMatch(
    lyrics,
    /SYNCHRONISED LYRICS|LOCAL FILES ONLY|id: heading/,
  );
  assert.match(lyrics, /No local track · Lyrics are never fetched online/);
  assert.match(lyrics, /height: parent.height/);
  assert.match(
    media,
    /id: frequencyLabels[\s\S]*?visible: content\.visualizerMode !== "off"/,
  );
  assert.match(
    media,
    /id: spectrumSlot[\s\S]*?visible: content\.visualizerMode !== "off" \|\| content\.lyricsVisible/,
  );
  assert.match(
    media,
    /id: spectrumSlot[\s\S]*?height: visible \? implicitHeight : 0/,
  );
  assert.match(media, /id: frequencyLabels[\s\S]*?z: 1/);
  assert.match(
    qml("SpectrumVisualizer.qml"),
    /root.mode === "curve" \|\| opacity > 0.01/,
  );
});
