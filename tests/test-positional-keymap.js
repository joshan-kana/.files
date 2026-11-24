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
      '(import ./modules/desktop/hyprland/keybindings.nix).bindings { terminal = "terminal"; browser = "browser"; }',
    ],
    { cwd: repo, encoding: "utf8" },
  ),
);

function chord(binding) {
  const modifier = binding.mods.flatMap((name) =>
    name === "meh"
      ? ["CTRL", "ALT", "SHIFT"]
      : name === "main"
        ? ["SUPER"]
        : [name.toUpperCase()],
  );
  return [...modifier, binding.key].join("+").toUpperCase();
}

const global = new Map(
  bindings
    .filter((binding) => binding.submap === null)
    .map((binding) => [chord(binding), binding.description]),
);

test("hub tab keys derive from the canonical workspace navigation bindings", () => {
  const previous = bindings.find(
    (binding) => binding.id === "workspace.previous",
  );
  const next = bindings.find((binding) => binding.id === "workspace.next");
  assert.equal(previous.key, "I");
  assert.equal(next.key, "O");
  const shell = fs.readFileSync(
    path.join(repo, "modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  assert.match(shell, /hubPrevious = navigationKey "workspace.previous"/);
  assert.match(shell, /hubNext = navigationKey "workspace.next"/);
});

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
    ["SUPER+I", "Previous workspace"],
    ["SUPER+O", "Next workspace"],
    ["SUPER+SHIFT+I", "Move window to previous workspace"],
    ["SUPER+SHIFT+O", "Move window to next workspace"],
    ["SUPER+SHIFT+Z", "Inspect current system and input state"],
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

test("all directional widgets delegate keys to the shared navigation mapping", () => {
  const runtime = qml("RuntimeConfig.qml");
  assert.match(runtime, /ShellKeybindings\.navigates\(shellBindings,/);
  for (const name of [
    "SystemContent.qml",
    "ScreenshotPicker.qml",
    "ResizeOverlay.qml",
    "OverviewPanel.qml",
    "CalendarContent.qml",
    "MediaContent.qml",
    "NotificationContent.qml",
    "AudioMixerContent.qml",
  ]) {
    const source = qml(name);
    for (const direction of ["left", "right", "up", "down"]) {
      if (
        name === "MediaContent.qml" &&
        ["left", "right"].includes(direction)
      ) {
        const action = direction === "left" ? "back" : "forward";
        for (const suffix of ["", "Arrow"])
          assert.ok(
            source.includes(
              `shellMatchesHint("MediaTransport.${action}${suffix}",`,
            ),
          );
        // The evaluated registry and remapping of these directional actions
        // are exercised in test-shell-keybindings.js.
      } else {
        assert.ok(
          new RegExp('shellNavigates\\("[^"]+", "' + direction + '",').test(
            source,
          ),
          name + ": missing " + direction + " navigation",
        );
      }
    }
  }
});

test("U/D paging and PageUp/PageDown survive throughout Controls and list views", () => {
  const host = qml("ShellExpansionHost.qml");
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.controlsPageUp"\)/,
  );
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.controlsPageDown"\)/,
  );
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.pageUp"\)/,
  );
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.pageDown"\)/,
  );
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
      assert.match(
        source,
        new RegExp(`shellKeyCode\\("[^"]+", "${key}"\\)`),
        `${name}: ${key}`,
      );
  }

  const controls = qml("SystemContent.qml");
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "D"\)\)\s*\{\s*recordingsPanel\.invoke\("requestDelete"\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "PageDown"\) \|\| \(event\.key === root\.runtime\.shellKeyCode\("controls", "D"\) && \(root\.runtime\.shellModifier\("controls", "Shift", event\.modifiers\)\)\)/,
  );
});

test("capture confirmation uses Enter, never Space", () => {
  const source = qml("ScreenshotPicker.qml");
  assert.match(
    source,
    /event\.key === picker\.runtime\.shellKeyCode\("capture", "Return"\) \|\| event\.key === picker\.runtime\.shellKeyCode\("capture", "Enter"\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*picker\.capture\(""/,
  );
  assert.doesNotMatch(
    source,
    /event\.key === picker\.runtime\.shellKeyCode\("capture", "Space"\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*picker\.capture\(""/,
  );
  assert.match(
    source,
    /shortcut: picker\.runtime\.shellHint\("ScreenshotPicker.capture"\)/,
  );
  assert.match(
    source,
    /event\.key === picker\.runtime\.shellKeyCode\("capture", "E"\)\)/,
  );
});

test("Compact Media advertises the direct Now Playing key and shares its destination", () => {
  const controls = qml("SystemContent.qml");
  const card = qml("ControlsMediaCard.qml");
  assert.match(
    controls,
    /shellMatchesHint\("ControlsMediaCard\.open", event\.key, event\.modifiers\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*mediaCard\.triggerOpen\(\)/,
  );
  assert.match(card, /onActivated: card.fullRequested\(\)/);
  assert.match(controls, /onFullRequested: root.mediaRequested\(\)/);
  assert.match(
    controls,
    /shellMatchesHint\("ControlsMediaCard\.open", event\.key, event\.modifiers\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*mediaCard\.triggerOpen\(\)/,
  );
});

test("mixer and device hints match the shared Controls keyboard dispatcher", () => {
  const mixer = qml("AudioMixerContent.qml");
  const device = qml("AudioDeviceControl.qml");
  const controls = qml("SystemContent.qml");
  assert.match(
    controls,
    /shellMatchesHint\("AudioMixerContent\.open", event\.key, event\.modifiers\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*audioDeck\.triggerOpen\(\)/,
  );
  assert.match(mixer, /onActivated: mixer.expandRequested\(\)/);
  assert.doesNotMatch(mixer, /id: expandAction/);
  assert.match(
    device,
    /shortcut: deviceControl\.runtime\.shellHint\("AudioDeviceControl.chooser"\)/,
  );
  assert.match(device, /visible: deviceControl.selected/);
  assert.match(device, /visible: !deviceControl.selected[\s\S]*?text: "⌄"/);
  assert.doesNotMatch(device, /shortcut:[^\n]*: "⌄"/);
  assert.match(
    controls,
    /shellMatchesHint\("AudioMixerContent\.open", event\.key, event\.modifiers\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*audioDeck\.triggerOpen\(\)/,
  );
  assert.match(
    controls,
    /root\.runtime\.shellMatchesHint\("AudioDeviceControl\.chooser", event\.key, event\.modifiers\)\)\s*\{\s*if \(!event\.isAutoRepeat\)\s*root\.toggleSelectedAudioDeviceChooser\(\)/,
  );
  assert.match(controls, /if \(audioDeck\.deviceChooserOpen\) \{/);
});

test("Bluetooth scanning hints never advertise paging's plain D key", () => {
  const bluetooth = qml("BluetoothPanel.qml");
  const controls = qml("SystemContent.qml");
  assert.match(
    bluetooth,
    /shortcut: panel\.runtime\.shellHint\("BluetoothPanel.scan"\),\s*label: "Scan"/,
  );
  assert.match(
    bluetooth,
    /text: panel\.system\.bluetoothDiscovering \? "Scanning for devices…" : "No devices found"/,
  );
  assert.doesNotMatch(bluetooth, /NO DEVICES \/\/ PRESS SHIFT\+D TO SCAN/);
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "D"\) && \(root\.runtime\.shellModifier\("controls", "Shift", event\.modifiers\)\)\)\s*\{\s*bluetoothPanel\.invoke\("toggleDiscovery"\)/,
  );
  assert.match(
    controls,
    /event\.key === root\.runtime\.shellKeyCode\("controls", "D"\) && !\(root\.runtime\.shellModifier\("controls", "Shift", event\.modifiers\)\)/,
  );
});

test("Bluetooth shortcut hints reflect available hardware and selected device state", () => {
  const bluetooth = qml("BluetoothPanel.qml");
  assert.match(
    bluetooth,
    /"PAIR FIRST \/\/ PRESS " \+ runtime\.shellHint\("BluetoothPanel\.pair"\)/,
  );
  assert.match(
    bluetooth,
    /"CONFIRM FORGET \/\/ PRESS " \+ runtime\.shellHint\("BluetoothPanel\.forget"\)/,
  );
  assert.doesNotMatch(bluetooth, /PRESS [PF](?: AGAIN)?"/);
  assert.match(
    bluetooth,
    /idleMessage: !panel\.adapterAvailable \? "Bluetooth adapter unavailable"/,
  );
  assert.match(
    bluetooth,
    /shortcut: panel\.runtime\.shellHint\("BluetoothPanel.radio"\),\s*label: "Radio",\s*visible: panel\.adapterAvailable/,
  );
  assert.match(
    bluetooth,
    /shortcut: panel\.runtime\.shellHint\("BluetoothPanel.scan"\),\s*label: "Scan",\s*visible: panel\.adapterAvailable && panel\.system\.bluetoothEnabled/,
  );
  assert.match(
    bluetooth,
    /shortcut: panel\.runtime\.shellHint\("BluetoothPanel.activate"\),\s*label: panel\.selectedDevice\(\)\?\.connected \? "Drop" : "Link"/,
  );
  assert.match(
    bluetooth,
    /visible: panel\.adapterAvailable && panel\.system\.bluetoothEnabled && panel\.selectedDevice\(\)\?\.paired === true/,
  );
  assert.match(
    bluetooth,
    /label: panel\.selectedDevice\(\)\?\.trusted \? "Untrust" : "Trust"/,
  );
  assert.match(
    qml("RecordingLibrary.qml"),
    /idleMessage: library\.entries\.length > 0 \? "Choose a capture to open or share" : "No saved captures"/,
  );
});

test("capture status messages and button hints agree that Enter confirms", () => {
  const source = qml("ScreenshotPicker.qml");
  assert.doesNotMatch(source, /SPACE TO (CONFIRM|RECORD|CAPTURE)/);
  assert.match(
    source,
    /picker\.runtime\.shellHint\("ScreenshotPicker\.capture"\) \+ " TO CONFIRM"/,
  );
  assert.match(
    source,
    /picker\.runtime\.shellHint\("ScreenshotPicker\.capture"\) \+ " TO RECORD"/,
  );
  assert.match(
    source,
    /picker\.runtime\.shellHint\("ScreenshotPicker\.capture"\) \+ " TO CAPTURE"/,
  );
  assert.match(
    source,
    /shortcut: picker\.runtime\.shellHint\("ScreenshotPicker.capture"\)/,
  );
  assert.match(source, /picker\.capture\(""/);
});
