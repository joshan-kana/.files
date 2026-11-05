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

test("local lyrics hint sits in the gap below the clipped spectrum, not across its edge", () => {
  const media = qml("MediaContent.qml");
  const lyrics = qml("MediaLyrics.qml");
  const footer = media.split("id: lyricsFooter")[1].split("id: transport")[0];
  assert.ok(footer);
  assert.match(footer, /top: spectrumSlot\.bottom/);
  assert.match(
    footer,
    /topMargin: Math\.max\(0, \(transport\.anchors\.topMargin - implicitHeight\) \/ 2\)/,
  );
  assert.match(footer, /visible: content\.engaged && content\.lyricsVisible/);
  assert.match(footer, /LOCAL FILES ONLY/);
  assert.doesNotMatch(lyrics, /LOCAL FILES ONLY|id: footer/);
  assert.match(
    lyrics,
    /height: parent\.height - heading\.height - parent\.spacing/,
  );
  // Keep the help line between the visualizer edge and the seek controls.
  for (const gap of [12, 24]) {
    for (const textHeight of [9, 10, 11, 12]) {
      const offset = Math.max(0, (gap - textHeight) / 2);
      assert.ok(offset + textHeight <= gap, `footer fits ${gap}px slot`);
    }
  }
});
