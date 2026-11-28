const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );
const nix = fs.readFileSync(
  path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
  "utf8",
);

test("emoji and other palette text use the text clipboard executable, not the cliphist ID helper", () => {
  const source = qml("CommandPalette.qml");
  assert.match(
    source,
    /calculationCopy\.exec\(\[runtime\.copyText, "--type", "text\/plain;charset=utf-8", value\]\)/,
  );
  assert.match(
    source,
    /entry\.kind === "calculation" \|\| entry\.kind === "symbol" \|\| entry\.kind === "snippet"/,
  );
  assert.match(
    source,
    /copyText\(entry\.kind === "snippet" \? entry\.snippetText : entry\.result, keepOpen\)/,
  );
  assert.doesNotMatch(
    source,
    /calculationCopy\.exec\(\[runtime\.clipboardCopy/,
  );
  assert.match(nix, /copyText = lib\.getExe' pkgs\.wl-clipboard "wl-copy"/);
});

test("Now Playing recovers the active focus scope after Controls disengages", () => {
  const source = qml("MediaContent.qml");
  assert.match(source, /onActiveFocusChanged: \{/);
  assert.match(source, /Qt\.callLater\(\(\) => \{/);
  assert.match(
    source,
    /content\.engaged && !content\.activeFocus && content\.Window\.window\.active/,
  );
  assert.match(source, /content\.forceActiveFocus\(\)/);
  assert.match(
    source,
    /Keys\.onPressed: event => \{[\s\S]*?!content\.engaged[\s\S]*?shellMatchesHint\("MediaContent\.lyrics", event\.key, event\.modifiers\)/,
  );
});

test("player preference uses one action and keeps reset alongside the other header utility", () => {
  const source = qml("MediaContent.qml");
  const state = qml("MediaState.qml");
  assert.match(source, /id: preferredAction/);
  assert.match(
    source,
    /title: content\.media\.persistentPreference !== "" \? "Use auto selection" : "Prefer current app"/,
  );
  assert.match(
    source,
    /shortcut: content\.runtime\.shellHint\("MediaContent\.prefer"\)/,
  );
  assert.match(
    source,
    /onActivated: content\.media\.togglePreferredPlayer\(\)/,
  );
  assert.match(source, /preferredAction\.trigger\(\)/);
  assert.equal((source.match(/id: preferredAction/g) || []).length, 1);
  assert.doesNotMatch(
    source,
    /id: preferenceChoices|model: \["Auto", "Prefer app"\]/,
  );
  assert.ok(
    source.indexOf("id: resetPreferredAction") <
      source.indexOf("id: spectrumSlot"),
  );
  assert.ok(
    source.indexOf("id: resetPreferredAction") <
      source.indexOf("id: preferredAction"),
  );
  assert.match(
    source,
    /width: Math\.max\(1, parent\.width - resetPreferredAction\.width/,
  );
  assert.match(state, /function togglePreferredPlayer\(\): void/);
});

test("each spectrum preview uses its destination density without duplicate per-surface constants", () => {
  const render = qml("SpectrumVisualizer.qml");
  assert.match(render, /surfaceKey === "wallpaperVisualizerMode" \? 64/);
  assert.match(
    render,
    /surfaceKey === "islandVisualizerMode" \|\| surfaceKey === "controlsVisualizerMode" \? 24/,
  );
  for (const name of [
    "WallpaperSpectrum.qml",
    "NowPlayingIsland.qml",
    "ControlsMediaCard.qml",
    "MediaContent.qml",
    "SettingsDetail.qml",
  ])
    assert.doesNotMatch(qml(name), /baseDensity:/);
  assert.match(nix, /spectrumOpacity = \{[\s\S]*?min = 0\.25;\s*max = 1\.0;/);
});

test("configured theme cancellation and authentication identity switching own their shortcut handlers", () => {
  assert.match(
    qml("SystemContent.qml"),
    /shellMatchesHint\("ThemePanel\.cancel", event\.key, event\.modifiers\)/,
  );
  assert.match(
    qml("PolkitDialog.qml"),
    /shellMatchesHint\("PolkitDialog\.identity", event\.key, event\.modifiers\)/,
  );
});

test("Spectrum settings contain no hidden wallpaper master toggle while keeping the global action", () => {
  const settings = qml("SettingsDetail.qml");
  const controls = qml("SystemContent.qml");
  const shell = qml("shell.qml");
  const actions = qml("Actions.qml");
  assert.doesNotMatch(
    settings,
    /wallpaperSpectrumToggleRequested|case "spectrum":\s*wallpaperSpectrumToggleRequested/,
  );
  assert.doesNotMatch(controls, /wallpaperSpectrumToggleRequested/);
  assert.match(actions, /commandId === "media.wallpaperSpectrum"/);
  assert.match(
    shell,
    /onWallpaperSpectrumToggleRequested: qmlAppearance.toggleWallpaperSpectrum\(\)/,
  );
});

test("native curve uses the original quadratic control points and straight terminal edge", () => {
  const native = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/visuals/plugin.cpp",
    ),
    "utf8",
  );
  assert.match(
    native,
    /segmentCount = std::max\(0, count - 2\) \* subdivisions \+ 1/,
  );
  assert.match(native, /for \(int i = 1; i < count - 1; \+\+i\)/);
  assert.match(
    native,
    /const QPointF start = previous, end = \(control \+ next\) \* 0\.5/,
  );
  assert.match(native, /paintSegment\(count > 1 \? sample\(count - 1\)/);
});

test("Now Playing measures only actual controls when both visualisations and lyrics are off", () => {
  const media = qml("MediaContent.qml");
  assert.match(
    media,
    /implicitHeight: visualizerMode === "off" && !lyricsVisible \? header\.y \+ header\.implicitHeight/,
  );
  assert.match(
    media,
    /transport\.implicitHeight \+ mediaActions\.anchors\.topMargin \+ mediaActions\.implicitHeight/,
  );
});

test("single preference action handles a saved preference even when another session player is active", () => {
  const source = qml("MediaContent.qml");
  const state = qml("MediaState.qml");
  assert.match(source, /active: content\.media\.persistentPreference !== ""/);
  assert.match(
    source,
    /enabled: content\.media\.available \|\| content\.media\.persistentPreference !== ""/,
  );
  assert.match(state, /if \(persistentPreference !== "" \|\| !available\)/);
});

test("hidden visualiser contributes neither content nor vertical margins", () => {
  const media = qml("MediaContent.qml");
  assert.match(
    media,
    /id: spectrumSlot[\s\S]*?visible: content\.visualizerMode !== "off" \|\| content\.lyricsVisible/,
  );
  assert.match(
    media,
    /topMargin: spectrumSlot\.visible \? \(content\.compactHeight \? content\.theme\.spacing3 : content\.theme\.spacing5\) : 0/,
  );
  assert.match(
    media,
    /topMargin: spectrumSlot\.visible \? \(content\.compactHeight \? content\.theme\.spacing3 : content\.theme\.spacing5\) : content\.theme\.spacing3/,
  );
});
