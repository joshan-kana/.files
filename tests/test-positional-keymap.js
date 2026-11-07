const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const repo = path.join(__dirname, "..");
const qml = (name) =>
  fs.readFileSync(
    path.join(repo, "modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

const bindings = JSON.parse(
  execFileSync(
    "nix",
    [
      "eval",
      "--impure",
      "--json",
      "--expr",
      'import ./modules/desktop/hyprland/keybindings.nix { terminal = "terminal"; browser = "browser"; }',
    ],
    { cwd: repo, encoding: "utf8" },
  ),
);

function chord(binding) {
  const modifier = binding.mehMod
    ? ["CTRL", "ALT", "SHIFT"]
    : binding.mainMod
      ? ["SUPER"]
      : [];
  return [...modifier, ...binding.keys.split(/\s*\+\s*/)]
    .join("+")
    .toUpperCase();
}

const global = new Map(
  bindings
    .filter((binding) => binding.submap === null)
    .map((binding) => [chord(binding), binding.description]),
);

test("all physical chords are unique within each compositor submap", () => {
  const seen = new Set();
  for (const binding of bindings) {
    const key = `${binding.submap || "global"}:${chord(binding)}`;
    assert.ok(!seen.has(key), `Duplicate keyboard shortcut: ${key}`);
    seen.add(key);
  }
});

test("frequent window operations and the local workspace scratchpad stay direct", () => {
  const expected = new Map([
    ["SUPER+F", "Toggle fullscreen"],
    ["SUPER+SHIFT+F", "Toggle floating"],
    ["SUPER+ALT+F", "Pin window"],
    ["SUPER+E", "Park or restore window in this workspace's scratchpad"],
    ["SUPER+SHIFT+E", "Open or leave this workspace's scratchpad"],
    ["SUPER+R", "Resize window with a visual keyboard mode"],
    ["SUPER+G", "Toggle pseudo tiling"],
    ["SUPER+X", "Toggle special workspace"],
    ["SUPER+SHIFT+X", "Send window to special workspace"],
    ["SUPER+SPACE", "App & command launcher"],
    ["SUPER+TAB", "Workspaces & window overview"],
  ]);
  for (const [key, description] of expected)
    assert.equal(global.get(key), description, key);
  assert.ok(!global.has("SUPER+CTRL+P"));
});

test("desktop destinations, capture, media, and workspace pairs have no old aliases", () => {
  const expected = new Map([
    ["SUPER+A", "Open Home tab"],
    ["SUPER+S", "Open Controls tab"],
    ["SUPER+D", "Open Activity tab"],
    ["SUPER+W", "Wallpaper gallery"],
    ["SUPER+SHIFT+W", "Toggle wallpaper spectrum"],
    ["SUPER+P", "Screenshot"],
    ["SUPER+SHIFT+P", "Screen record"],
    ["SUPER+ALT+P", "Capture history"],
    ["SUPER+M", "Application mixer"],
    ["SUPER+N", "Now playing"],
    ["SUPER+U", "Previous workspace"],
    ["SUPER+O", "Next workspace"],
    ["SUPER+SHIFT+U", "Move window to previous workspace"],
    ["SUPER+SHIFT+O", "Move window to next workspace"],
  ]);
  for (const [key, description] of expected)
    assert.equal(global.get(key), description, key);
  for (const old of [
    "SUPER+SHIFT+S",
    "SUPER+SHIFT+R",
    "SUPER+SHIFT+G",
    "SUPER+SHIFT+V",
  ]) {
    if (old === "SUPER+SHIFT+V") {
      assert.equal(global.get(old), "Move window to next display");
    } else {
      assert.ok(!global.has(old), `Stale alias: ${old}`);
    }
  }
  for (let number = 1; number <= 10; number++) {
    const key = String(number % 10);
    assert.equal(global.get(`SUPER+${key}`), `Workspace ${number}`);
    assert.equal(
      global.get(`SUPER+SHIFT+${key}`),
      `Move window to workspace ${number}`,
    );
  }
});

test("the right-hand MEH app grid is complete and unambiguous", () => {
  for (const [key, description] of [
    ["J", "Terminal"],
    ["K", "Browser"],
    ["L", "Visual Studio Code"],
    ["U", "Spotify"],
    ["I", "Thunderbird"],
    ["O", "Obsidian"],
    ["N", "Files"],
    ["M", "Floorp"],
    ["P", "Audio effects"],
    ["H", "Edit desktop configuration"],
  ])
    assert.equal(global.get(`CTRL+ALT+SHIFT+${key}`), description);
});

test("HJKL and arrow-key navigation both remain available in widgets", () => {
  for (const name of [
    "SystemContent.qml",
    "ScreenshotPicker.qml",
    "ResizeOverlay.qml",
    "OverviewPanel.qml",
    "CalendarContent.qml",
    "WeatherContent.qml",
    "MediaContent.qml",
    "NotificationContent.qml",
    "AudioMixerContent.qml",
  ]) {
    const source = qml(name);
    for (const key of ["H", "J", "K", "L", "Left", "Right", "Up", "Down"])
      assert.match(source, new RegExp(`Qt\\.Key_${key}\\b`), `${name}: ${key}`);
  }
});

test("U/D paging and PageUp/PageDown survive throughout Controls and list views", () => {
  const host = qml("ShellExpansionHost.qml");
  assert.match(host, /sequence: "U"/);
  assert.match(host, /sequence: "D"/);
  assert.match(host, /sequence: "PgUp"/);
  assert.match(host, /sequence: "PgDown"/);
  assert.match(host, /!host\.detailVisible/);
  assert.match(host, /!host\.helpVisible/);
  assert.match(host, /hostPageShortcutsEnabled/);

  for (const name of [
    "SystemContent.qml",
    "AudioMixerContent.qml",
    "NotificationContent.qml",
    "ClipboardPanel.qml",
    "CommandPalette.qml",
  ]) {
    const source = qml(name);
    for (const key of ["U", "D", "PageUp", "PageDown"])
      assert.match(source, new RegExp(`Qt\\.Key_${key}\\b`), `${name}: ${key}`);
  }

  const controls = qml("SystemContent.qml");
  assert.match(
    controls,
    /event\.key === Qt\.Key_D\)\s*\{\s*recordingsPanel\.invoke\("requestDelete"\)/,
  );
  assert.match(
    controls,
    /event\.key === Qt\.Key_PageDown \|\| \(event\.key === Qt\.Key_D && \(event\.modifiers & Qt\.ShiftModifier\)\)/,
  );
});

test("capture confirmation uses Enter, never Space", () => {
  const source = qml("ScreenshotPicker.qml");
  assert.match(
    source,
    /event\.key === Qt\.Key_Return \|\| event\.key === Qt\.Key_Enter\)\s*\{\s*picker\.capture\(""/,
  );
  assert.doesNotMatch(
    source,
    /event\.key === Qt\.Key_Space\)\s*\{\s*picker\.capture\(""/,
  );
  assert.match(source, /shortcut: "ENTER"/);
  assert.match(source, /event\.key === Qt\.Key_E\)/);
});

test("Compact Media advertises the direct Now Playing key and shares its destination", () => {
  const controls = qml("SystemContent.qml");
  const card = qml("ControlsMediaCard.qml");
  assert.match(card, /shortcut: "N"/);
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.match(controls, /onFullRequested: root.mediaRequested\(\)/);
  assert.match(
    controls,
    /event.key === Qt.Key_N\)\s*\{\s*root.mediaRequested\(\)/,
  );
});

test("mixer and device hints match the shared Controls keyboard dispatcher", () => {
  const mixer = qml("AudioMixerContent.qml");
  const device = qml("AudioDeviceControl.qml");
  const controls = qml("SystemContent.qml");
  assert.match(mixer, /shortcut: "SHIFT\+M"/);
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.doesNotMatch(mixer, /id: expandAction/);
  assert.match(device, /shortcut: deviceControl\.selected \? "P" : "⌄"/);
  assert.match(
    controls,
    /shifted && event\.key === Qt\.Key_M\)\s*\{\s*root\.openMixer\(\)/,
  );
  assert.match(
    controls,
    /event\.key === Qt\.Key_P\)\s*\{\s*root\.toggleSelectedAudioDeviceChooser\(\)/,
  );
  assert.match(controls, /if \(audioDeck\.deviceChooserOpen\) \{/);
});

test("Bluetooth scanning hints never advertise paging's plain D key", () => {
  const bluetooth = qml("BluetoothPanel.qml");
  const controls = qml("SystemContent.qml");
  assert.match(bluetooth, /shortcut: "SHIFT\+D",\s*label: "Scan"/);
  assert.match(bluetooth, /NO DEVICES \/\/ PRESS SHIFT\+D TO SCAN/);
  assert.match(
    controls,
    /event\.key === Qt\.Key_D && \(event\.modifiers & Qt\.ShiftModifier\)\)\s*\{\s*bluetoothPanel\.invoke\("toggleDiscovery"\)/,
  );
  assert.match(
    controls,
    /event\.key === Qt\.Key_D && !\(event\.modifiers & Qt\.ShiftModifier\)/,
  );
});

test("capture status messages and button hints agree that Enter confirms", () => {
  const source = qml("ScreenshotPicker.qml");
  assert.doesNotMatch(source, /SPACE TO (CONFIRM|RECORD|CAPTURE)/);
  assert.match(source, /ENTER TO CONFIRM/);
  assert.match(source, /ENTER TO RECORD/);
  assert.match(source, /ENTER TO CAPTURE/);
  assert.match(source, /shortcut: "ENTER"/);
  assert.match(source, /picker\.capture\(""/);
});
