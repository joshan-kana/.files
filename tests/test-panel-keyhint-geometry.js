const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const base = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (name) => fs.readFileSync(path.join(base, name + ".qml"), "utf8");

test("every shell panel uses the canonical keyboard and visible action primitives", () => {
  const panels = [
    "AudioMixerContent",
    "BluetoothPanel",
    "CalendarContent",
    "ClipboardPanel",
    "MediaContent",
    "NetworkPanel",
    "NotificationContent",
    "OverviewPanel",
    "SessionPanel",
    "StatusContent",
    "SystemContent",
    "ThemePanel",
    "VhsPanel",
    "WallpaperPanel",
    "WeatherContent",
  ];
  assert.equal(panels.length, 15);
  for (const name of panels) {
    const source = read(name);
    assert.match(
      source,
      /(?:KeyHint|KeyHintStrip|ShellAction|SessionActionButton|QuickSettingChip)\s*\{/,
      name + " must use a shared action or hint primitive",
    );
    assert.doesNotMatch(
      source,
      /shortcut:\s*"(?!")/,
      name + " must not hardcode active shortcuts",
    );
  }
  const hint = read("KeyHint");
  const strip = read("KeyHintStrip");
  const chord = read("KeyChord");
  assert.match(hint, /implicitWidth: \(hasShortcut \? cap\.width/);
  assert.match(hint, /implicitHeight: Math\.max/);
  assert.match(strip, /readonly property var wrappedRows/);
  assert.match(strip, /occupied \+ strip\.groupSpacing \+ width > limit/);
  assert.match(chord, /implicitWidth: chord\.implicitWidth/);
});

test("connectivity retains a full icon box and moves it past the left keycap", () => {
  const tile = read("ConnectivityTile");
  const controls = read("SystemContent");
  assert.match(tile, /width: 47\s+height: 47/);
  assert.match(tile, /font\.pixelSize: tile\.theme\.fontSize\(27\)/);
  assert.match(
    tile,
    /leftMargin: Math\.max\(tile\.theme\.spacing4, tile\.theme\.spacing2 \+ shortcutHint\.implicitWidth \+ tile\.theme\.spacing3\)/,
  );
  assert.match(
    tile,
    /width: Math\.max\(1, parent\.width - \(detailAction\.visible \? detailAction\.width \+ tile\.theme\.spacing2 : 0\)\)/,
  );
  assert.match(tile, /rightMargin: tile\.theme\.spacing4\s+\}/);
  assert.doesNotMatch(
    tile,
    /rightMargin: tile\.theme\.spacing4 \+ \(tile\.detailShortcut\.length/,
  );
  assert.match(
    tile,
    /id: detailAction[\s\S]*?shortcut: tile\.detailShortcut[\s\S]*?runtime: tile\.runtime/,
  );
  assert.match(
    controls,
    /dashboardBrightnessHeight: Math\.max\(90, theme\.fontSize\(66\) \+ theme\.spacing3 \* 2\)/,
  );
  assert.match(controls, /height: root\.dashboardBrightnessHeight/);
});

test("media and audio cards reserve measured top-left keycap safe space", () => {
  const media = read("ControlsMediaCard");
  const mixer = read("AudioMixerContent");
  const controls = read("SystemContent");
  assert.match(
    media,
    /contentTopInset: Math\.max\(theme\.spacing3, theme\.spacing2 \* 2 \+ theme\.keycapHeight\)/,
  );
  assert.match(
    media,
    /implicitHeight: Math\.max\(media\.available \? 178 : 152, controlsHeight \+ contentTopInset \+ theme\.spacing3\)/,
  );
  assert.match(media, /topMargin: card\.contentTopInset/);
  assert.match(
    media,
    /controlsHeight: heroSize \+ \(media\.available \? theme\.spacing2 \* 2 \+ Math\.max\(24, progressSlider\.implicitHeight\) \+ transportRow\.implicitHeight : 0\)/,
  );
  assert.doesNotMatch(media, /implicitHeight: .*content\.implicitHeight/);
  assert.match(media, /width: parent\.width\s+height: card\.heroSize/);
  assert.doesNotMatch(
    media,
    /parent\.width - \(openHint\.visible \? openHint\.implicitWidth/,
  );
  assert.match(
    mixer,
    /compactTopInset: Math\.max\(theme\.spacing4, theme\.spacing2 \* 2 \+ theme\.keycapHeight\)/,
  );
  assert.match(
    mixer,
    /y: mixer\.compact \? mixer\.compactTopInset : mixer\.theme\.spacing2/,
  );
  assert.match(
    mixer,
    /implicitHeight: body\.implicitHeight \+ \(compact \? compactTopInset \+ theme\.spacing3/,
  );
  assert.match(mixer, /TileKeyHint \{[\s\S]*?primary: false/);
  assert.match(
    controls,
    /height: Math\.max\(implicitHeight, mediaCard\.implicitHeight\)/,
  );
  assert.match(
    controls,
    /height: Math\.max\(implicitHeight, audioDeck\.implicitHeight\)/,
  );
});

test("buttons across panels own hints while decorative symbols are not fake shortcuts", () => {
  const tabs = read("HubTabs");
  assert.match(
    tabs,
    /id: backButton\s+width: Math\.max\(64, backHint\.implicitWidth/,
  );
  assert.match(
    tabs,
    /id: backHint[\s\S]*?shortcut: root\.runtime\.shellHint\("ShellExpansionHost\.back"\)/,
  );
  assert.match(tabs, /onActivated: root\.backRequested\(\)/);

  const resources = read("ResourceDashboard");
  assert.match(
    resources,
    /shortcut: panel\.runtime\.shellHint\("ResourceDashboard\.toggleCores"\)/,
  );
  assert.doesNotMatch(resources, /ResourceDashboard\.toggleCoresHint/);
  assert.match(resources, /action: "ResourceDashboard\.refresh"/);

  const recordings = read("RecordingLibrary");
  assert.match(
    recordings,
    /title: "Copy selection"\s+shortcut: library\.runtime\.shellHint\("RecordingLibrary\.copy"\)/,
  );
  assert.doesNotMatch(
    recordings.slice(
      recordings.indexOf("KeyHintStrip {", recordings.indexOf("id: footer")),
    ),
    /label: "Copy selection"/,
  );

  const device = read("AudioDeviceControl");
  assert.match(
    device,
    /shortcut: deviceControl\.runtime\.shellHint\("AudioDeviceControl\.chooser"\)/,
  );
  assert.match(device, /visible: !deviceControl\.selected[\s\S]*?text: "⌄"/);
  assert.doesNotMatch(device, /shortcut:[^\n]*"⌄"/);

  for (const [name, action] of [
    ["WeatherContent", "WeatherContent.refresh"],
    ["StatusContent", "StatusContent.refresh"],
  ]) {
    const panel = read(name);
    assert.match(panel, /ShellAction \{/);
    assert.match(panel, /inlineIconHint: true/);
    assert.ok(panel.includes('shellHint("' + action + '")'), action);
  }
});

test("compact controllers preserve direct positional action hints", () => {
  for (const name of ["ControlsMediaCard", "AudioMixerContent"]) {
    const src = read(name);
    assert.match(src, /TileKeyHint \{[\s\S]*?primary: false/);
    assert.match(
      src,
      /onActivated: (?:card\.fullRequested|mixer\.expandRequested)\(\)/,
    );
  }
  const tile = read("TileKeyHint");
  const secondary = read("TileCornerAction");
  assert.match(tile, /left: primary \? parent\.left : undefined/);
  assert.match(tile, /right: primary \? undefined : parent\.right/);
  assert.match(secondary, /anchors \{[\s\S]*?right: parent\.right/);
});
