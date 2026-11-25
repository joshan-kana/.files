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

test("player preference uses one connected choice group with independent reset", () => {
  const source = qml("MediaContent.qml");
  const state = qml("MediaState.qml");
  assert.match(source, /model: \["Auto", "Prefer app"\]/);
  assert.match(source, /delegate: ShellChoice \{/);
  assert.match(source, /choices: preferenceChoices/);
  assert.match(source, /content\.media\.useAutomaticSelection\(\)/);
  assert.match(source, /content\.media\.preferCurrentPlayer\(\)/);
  assert.match(source, /id: resetPreferredAction/);
  assert.doesNotMatch(
    source,
    /Use auto selection|text: content\.media\.preferenceStatus/,
  );
  assert.match(state, /function useAutomaticSelection\(\): void/);
  assert.match(state, /function preferCurrentPlayer\(\): void/);
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

test("preferred player selection reflects the saved preference even when another player is temporarily active", () => {
  const source = qml("MediaContent.qml");
  assert.match(
    source,
    /active: index === 0 \? content\.media\.persistentPreference === "" : content\.media\.persistentPreference !== ""/,
  );
  assert.match(
    source,
    /const next = content\.media\.persistentPreference !== "" \|\| !content\.media\.available \? 0 : 1/,
  );
});
