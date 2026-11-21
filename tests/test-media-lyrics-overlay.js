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
  assert.match(
    media,
    /visible: content\.visualizerMode === "curve" \|\| opacity > 0\.01/,
  );
  assert.match(
    media,
    /visible: content\.visualizerMode === "bars" \|\| opacity > 0\.01/,
  );
  assert.doesNotMatch(
    media,
    /!content\.lyricsVisible && \(content\.visualizerMode/,
  );
  assert.ok(
    media.indexOf("SpectrumCurve {") < media.indexOf("MediaLyrics {") &&
      media.indexOf("SpectrumBars {") < media.indexOf("MediaLyrics {"),
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

test("curve outline and fill share the existing spectrum gradient stops", () => {
  const curve = qml("SpectrumCurve.qml");
  assert.match(curve, /let ribbon = outline/);
  assert.match(curve, /path: root\.geometry\.ribbon/);
  for (const p of ["0", "0.5", "1"])
    assert.ok(curve.includes(`root.theme.spectrumColor(${p})`));
  assert.doesNotMatch(curve, /theme\.spectrumColor\(0\.68\)/);
  assert.match(curve, /x2: root\.width/);
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
  assert.match(media, /id: frequencyLabels[\s\S]*?visible: true/);
  assert.match(media, /id: frequencyLabels[\s\S]*?z: 1/);
  assert.match(
    media,
    /visible: content.visualizerMode === "curve" \|\| opacity > 0.01/,
  );
});
