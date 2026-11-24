const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const dir = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qmlDir = path.join(dir, "qml");
const source = fs.readFileSync(path.join(dir, "keybindings.nix"), "utf8");
const globalSource = fs.readFileSync(
  path.join(dir, "../keybindings.nix"),
  "utf8",
);
const { execFileSync } = require("node:child_process");
const registry = JSON.parse(
  execFileSync(
    "nix",
    [
      "eval",
      "--impure",
      "--json",
      "--expr",
      "import ./modules/desktop/hyprland/shell/keybindings.nix",
    ],
    { cwd: path.join(__dirname, ".."), encoding: "utf8" },
  ),
);
const { base, navigation, hints, actions: actionAssignments } = registry;
const Qt = {};
for (const [
  i,
  name,
] of "Escape Return Enter Tab Backtab Backspace Space Delete Up Down Left Right PageUp PageDown Shift Alt Control Meta AltGr Slash Question Minus Underscore Plus Equal BracketLeft BracketRight Comma Period"
  .split(" ")
  .entries())
  Qt[`Key_${name}`] = 0x110000 + i;
Object.assign(Qt, {
  ShiftModifier: 1,
  AltModifier: 2,
  ControlModifier: 4,
  MetaModifier: 8,
});
const f = vm.runInNewContext(
  fs.readFileSync(path.join(qmlDir, "ShellKeybindings.js"), "utf8") +
    "\n({assigned,keyCode,navigates,navigationHint,modifier,hint,sequence,matchesHint,numberIndex,numberHint,widgetChoiceIndex,widgetChoiceHint})",
);
const files = fs.readdirSync(qmlDir).filter((name) => name.endsWith(".qml"));

test("one declarative registry owns every local shortcut and its visible hint", () => {
  assert.ok(Object.keys(base).length > 40);
  assert.ok(Object.keys(hints).length > 200);
  for (const name of files) {
    const s = fs.readFileSync(path.join(qmlDir, name), "utf8");
    assert.doesNotMatch(
      s,
      /\b(?:shortcut|toggleShortcut|cancelShortcut|keyHint): "[^"\n]+"/,
      `${name}: literal keycap`,
    );
    assert.doesNotMatch(
      s,
      /\bsequence: "[^"\n]+"/,
      `${name}: literal sequence`,
    );
    for (const m of s.matchAll(
      /\.shell(?:Hint|Sequence|MatchesHint)\("([^"\n]+)"/g,
    ))
      assert.ok(
        hints[m[1]] ||
          actionAssignments[m[1]] ||
          (name === "SessionPanel.qml" && m[1] === "SessionPanel."),
        `${name}: missing action ${m[1]}`,
      );
    for (const m of s.matchAll(/\.shellKeyCode\("([^"\n]+)", "([^"\n]+)"\)/g))
      assert.ok(base[m[2]], `${name}: missing slot ${m[1]}.${m[2]}`);
    for (const m of s.matchAll(/\.shellModifier\("([^"\n]+)", "([^"\n]+)"/g))
      assert.ok(base[m[2]], `${name}: missing modifier ${m[1]}.${m[2]}`);
  }
});

test("remapping an assigned key changes dispatch and every related hint together", () => {
  assert.equal(f.keyCode(registry, "controls", "Q", Qt), 81);
  assert.equal(f.keyCode(registry, "controls", "Escape", Qt), Qt.Key_Escape);
  assert.equal(
    f.keyCode(registry, "controls", "PageDown", Qt),
    Qt.Key_PageDown,
  );
  assert.equal(f.keyCode(registry, "controls", "Tab", Qt), Qt.Key_Tab);
  assert.equal(f.keyCode(registry, "controls", "Return", Qt), Qt.Key_Return);
  assert.equal(f.hint(registry, "SystemContent.themes"), "Q");
  assert.equal(f.hint(registry, "SessionPanel.lock"), "Q");
  const changed = { ...registry, overrides: { controls: { Q: "Z", H: "M" } } };
  assert.equal(f.keyCode(changed, "controls", "Q", Qt), 90);
  assert.equal(f.hint(changed, "SystemContent.themes"), "Z");
  assert.equal(f.hint(changed, "SessionPanel.lock"), "Z");
  assert.equal(
    f.hint(changed, "ThemePanel.columns"),
    f.hint(registry, "ThemePanel.columns").replace("H/", "M/"),
  );
  assert.equal(f.keyCode(changed, "calendar", "H", Qt), 72);
  assert.equal(
    f.hint(changed, "CalendarContent.days"),
    f.hint(registry, "CalendarContent.days"),
  );
  assert.equal(f.matchesHint(changed, "SessionPanel.lock", 90, 0, Qt), true);
  assert.equal(f.matchesHint(changed, "SessionPanel.lock", 81, 0, Qt), false);
});

test("palette Enter closes and Shift+Enter preserves the open palette", () => {
  assert.equal(f.modifier(registry, "palette", "Shift", 0, Qt), false);
  assert.equal(
    f.modifier(registry, "palette", "Shift", Qt.ShiftModifier, Qt),
    true,
  );
  const palette = fs.readFileSync(
    path.join(qmlDir, "CommandPalette.qml"),
    "utf8",
  );
  const dispatches = palette.match(
    /palette\.launchCurrent\(palette\.runtime\.shellModifier\("palette", "Shift", event\.modifiers\)\)/g,
  );
  assert.equal(
    dispatches?.length,
    2,
    "search and results must both forward a boolean keepOpen",
  );
});

test("modifier changes, alternatives and special keys remain consistent", () => {
  const changed = {
    ...registry,
    overrides: {
      controls: { Shift: "ALT", D: "M", X: "Z", T: "B" },
      palette: { Alt: "CTRL" },
      capture: { Slash: "Y" },
    },
  };
  assert.equal(
    f.modifier(changed, "controls", "Shift", Qt.AltModifier, Qt),
    true,
  );
  assert.equal(
    f.modifier(changed, "controls", "Shift", Qt.ShiftModifier, Qt),
    false,
  );
  assert.equal(f.hint(changed, "BluetoothPanel.scan"), "ALT+M");
  assert.equal(
    f.matchesHint(changed, "BluetoothPanel.scan", 77, Qt.AltModifier, Qt),
    true,
  );
  assert.equal(
    f.matchesHint(changed, "BluetoothPanel.scan", 77, Qt.ShiftModifier, Qt),
    false,
  );
  assert.equal(
    f.matchesHint(changed, "BluetoothPanel.scan", 68, Qt.AltModifier, Qt),
    false,
  );
  assert.equal(f.hint(changed, "ThemePanel.cancel"), "Z");
  assert.equal(f.hint(changed, "SystemContent.nightLight"), "T");
  assert.equal(f.hint(changed, "ThemePanel.search"), "/");
  assert.equal(f.hint(changed, "ScreenshotPicker.cancel"), "ESC");
  assert.equal(f.sequence(changed, "CommandPalette.apps"), "Ctrl+2");
  assert.equal(f.hint(registry, "OverviewPanel.workspace"), "1–0");
});

test("direction bindings drive both navigation and action-owned hints", () => {
  const directions = Object.keys(navigation);
  assert.equal(directions.length, 4);
  const changed = {
    ...registry,
    navigation: Object.fromEntries(
      directions.map((direction, index) => [
        direction,
        ["VWXY"[index], "1234"[index]],
      ]),
    ),
  };

  for (const direction of directions) {
    const [primary, alternative] = changed.navigation[direction];
    const primaryKey = f.keyCode(changed, "controls", primary, Qt);
    const alternateKey = f.keyCode(changed, "controls", alternative, Qt);
    assert.equal(
      f.navigates(changed, "controls", direction, primaryKey, Qt),
      true,
    );
    assert.equal(
      f.navigates(changed, "controls", direction, alternateKey, Qt),
      true,
    );
    assert.equal(
      f.navigates(changed, "controls", direction, primaryKey, Qt, "arrows"),
      false,
    );
    assert.equal(
      f.navigates(changed, "controls", direction, alternateKey, Qt, "primary"),
      false,
    );
  }

  const directionalHints = Object.entries(hints).filter(([, entry]) =>
    /NAV_(?:HORIZONTAL|VERTICAL|ALL)/.test(entry.template),
  );
  assert.ok(directionalHints.length > 0);
  for (const [action, { scope, template }] of directionalHints) {
    const original = f.hint(registry, action);
    const changedHint = f.hint(changed, action);
    assert.notEqual(changedHint, original, action);
    for (const [, token] of [
      ...template.matchAll(
        /(NAV_(?:HORIZONTAL|VERTICAL|ALL)(?:_PRIMARY)?(?:_ARROWS)?(?:_SHIFT)?)/g,
      ),
    ])
      assert.ok(
        changedHint.includes(f.navigationHint(changed, scope, token)),
        action,
      );
  }
});

test("shell-local and compositor-global shortcuts have distinct owners", () => {
  const nix = fs.readFileSync(path.join(dir, "default.nix"), "utf8");
  const runtime = fs.readFileSync(
    path.join(qmlDir, "RuntimeConfig.qml"),
    "utf8",
  );
  const global = fs.readFileSync(path.join(dir, "../keybindings.nix"), "utf8");
  assert.match(nix, /shellBindings = import \.\/keybindings\.nix/);
  assert.match(
    nix,
    /keybindings = \(import \.\.\/keybindings\.nix\)\.bindings/,
  );
  assert.match(
    runtime,
    /ShellKeybindings\.keyCode\(shellBindings, scope, slot, Qt\)/,
  );
  assert.match(runtime, /ShellKeybindings\.hint\(shellBindings, action\)/);
  assert.match(global, /id = "status\.inspect"/);
  assert.match(global, /navigation = \{/);
  assert.match(source, /import \.\.\/keybindings\.nix/);
  assert.match(global, /navigationKey = direction:/);
  for (const direction of Object.keys(navigation))
    assert.ok(global.includes('navigationKey "' + direction + '"'));
});

test("numbered actions use the assigned key for each index, not a contiguous keycode range", () => {
  assert.equal(f.numberIndex(registry, "activity", 49, 9, Qt), 0);
  assert.equal(f.numberIndex(registry, "activity", 57, 9, Qt), 8);
  const remapped = { ...registry, overrides: { activity: { 1: "9", 9: "1" } } };
  assert.equal(f.numberIndex(remapped, "activity", 49, 9, Qt), 8);
  assert.equal(f.numberIndex(remapped, "activity", 57, 9, Qt), 0);
  assert.equal(f.numberHint(remapped, "activity", 0), "9");
  assert.equal(f.numberHint(remapped, "activity", 8), "1");
  for (const name of ["OverviewPanel.qml"])
    assert.match(
      fs.readFileSync(path.join(qmlDir, name), "utf8"),
      /shellNumberIndex/,
    );
  assert.match(
    fs.readFileSync(path.join(qmlDir, "NotificationCard.qml"), "utf8"),
    /shellChoiceHint/,
  );
});

test("semantic action bindings change their handler and hint without changing a shared slot", () => {
  assert.ok(Object.keys(actionAssignments).length >= 4);
  const custom = {
    ...registry,
    actions: { ...registry.actions, "SystemContent.frame": "ALT+Z" },
  };
  assert.equal(f.hint(custom, "SystemContent.frame"), "ALT+Z");
  assert.equal(
    f.hint(custom, "SystemContent.idleInhibited"),
    f.hint(registry, "SystemContent.idleInhibited"),
  );
  assert.equal(f.keyCode(custom, "controls", "S", Qt), 83);
  assert.equal(
    f.matchesHint(custom, "SystemContent.frame", 90, Qt.AltModifier, Qt),
    true,
  );
  assert.equal(
    f.matchesHint(custom, "SystemContent.frame", 83, Qt.ShiftModifier, Qt),
    false,
  );
  assert.equal(
    f.matchesHint(custom, "SystemContent.frame", 90, Qt.ShiftModifier, Qt),
    false,
  );
  const controls = fs.readFileSync(
    path.join(qmlDir, "SystemContent.qml"),
    "utf8",
  );
  const reactive = fs.readFileSync(
    path.join(qmlDir, "ReactiveQuickControls.qml"),
    "utf8",
  );
  for (const action of Object.keys(actionAssignments)) {
    const contextual = action.startsWith("ReactiveQuickControls.");
    assert.ok(
      (contextual ? reactive : controls).includes(
        contextual
          ? `shellMatchesHint("${action}", key, modifiers)`
          : `shellMatchesHint("${action}", event.key, event.modifiers)`,
      ),
      action,
    );
  }
});

test("power, notifications and preset choices use positional shifted letters", () => {
  const detail = fs.readFileSync(
    path.join(qmlDir, "SettingsDetail.qml"),
    "utf8",
  );
  assert.match(detail, /shellChoiceIndex\(key, modifiers, 5\)/);
  assert.match(detail, /shellChoiceHint\(index\)/);
  assert.doesNotMatch(detail, /shellNumber(?:Index|Hint)/);
  assert.equal(f.widgetChoiceHint(registry, 0), "SHIFT+Q");
  assert.equal(f.widgetChoiceIndex(registry, 81, Qt.ShiftModifier, 9, Qt), 0);
  assert.equal(f.widgetChoiceIndex(registry, 81, 0, 9, Qt), -1);
  assert.equal(
    f.widgetChoiceIndex(registry, 81, Qt.ShiftModifier | Qt.AltModifier, 9, Qt),
    -1,
  );
  assert.equal(new Set(registry.widgetChoices).size, 9);
  assert.match(
    fs.readFileSync(path.join(qmlDir, "NotificationContent.qml"), "utf8"),
    /shellChoiceIndex/,
  );
});

test("compact detail open actions follow remapped keys in labels and dispatch", () => {
  for (const action of ["AudioMixerContent.open", "ControlsMediaCard.open"]) {
    assert.ok(f.hint(registry, action), `${action} must be assigned`);
    const rebound = {
      ...registry,
      actions: { ...actionAssignments, [action]: "ALT+Y" },
    };
    assert.equal(f.hint(rebound, action), "ALT+Y");
    assert.equal(f.matchesHint(rebound, action, 89, Qt.AltModifier, Qt), true);
    assert.equal(f.matchesHint(rebound, action, 89, 0, Qt), false);
  }
});

test("reactive details have independent plain-letter assignments", () => {
  for (const [name, key] of [
    ["musicReactiveDetails", "U"],
    ["wallpaperSpectrumDetails", "Y"],
  ]) {
    const id = "SystemContent." + name;
    assert.equal(f.hint(registry, id), key);
    assert.equal(f.matchesHint(registry, id, key.charCodeAt(0), 0, Qt), true);
    assert.equal(
      f.matchesHint(registry, id, key.charCodeAt(0), Qt.ShiftModifier, Qt),
      false,
    );
    assert.equal(
      f.matchesHint(registry, id, key.charCodeAt(0), Qt.AltModifier, Qt),
      false,
    );
  }
});

test("dashboard direct widget bindings are collision-free unmodified or shifted letters", () => {
  const actions = [
    "bar",
    "frame",
    "nightLight",
    "shellGlass",
    "vhsTune",
    "vhsToggle",
    "networkDetails",
    "bluetoothDetails",
    "brightnessFocus",
    "alertsDetails",
    "stayDetails",
    "powerDetails",
    "windowsDetails",
    "glassDetails",
    "nightLightDetails",
    "wallpaperSpectrumDetails",
    "musicReactiveDetails",
    "barDetails",
    "frameDetails",
    "motionDetails",
    "alerts",
    "bluetooth",
    "captures",
    "displays",
    "motion",
    "musicReactive",
    "network",
    "powerProfile",
    "reset",
    "resources",
    "statusInspection",
    "stayAwake",
    "themes",
    "wallpaper",
    "wallpaperSpectrum",
    "windowTransparency",
  ]
    .map((name) => "SystemContent." + name)
    .concat([
      "AudioMixerContent.open",
      "AudioDeviceControl.chooser",
      "AudioDeviceControl.mute",
      "AudioDeviceControl.muteMicrophone",
      "ControlsMediaCard.open",
      "ControlsMediaCard.repeat",
      "ControlsMediaCard.shuffle",
    ]);
  const seen = new Map(
    ["H", "J", "K", "L", "I", "O", "SHIFT+H", "SHIFT+L"].map((key) => [
      key,
      "reserved navigation",
    ]),
  );
  for (const action of actions) {
    const key = f.hint(registry, action);
    assert.match(key, /^(?:SHIFT\+)?[A-Z]$/, action);
    assert.ok(!seen.has(key), action + " collides with " + seen.get(key));
    seen.set(key, action);
  }
});

test("named-key and directional action hints dispatch the same assigned key", () => {
  assert.equal(
    f.matchesHint(registry, "DisplaySettings.apply", Qt.Key_Return, 0, Qt),
    true,
  );
  assert.equal(
    f.matchesHint(
      registry,
      "DisplaySettings.apply",
      Qt.Key_Return,
      Qt.ShiftModifier,
      Qt,
    ),
    false,
  );
  assert.equal(
    f.matchesHint(
      registry,
      "AudioMixerContent.balanceLeft",
      72,
      Qt.ShiftModifier,
      Qt,
    ),
    true,
  );
  assert.equal(
    f.matchesHint(registry, "AudioMixerContent.balanceLeft", 72, 0, Qt),
    false,
  );
  const changed = { ...registry, overrides: { controls: { Return: "Z" } } };
  assert.equal(f.hint(changed, "DisplaySettings.apply"), "Z");
  assert.equal(
    f.matchesHint(changed, "DisplaySettings.apply", 90, 0, Qt),
    true,
  );
});

test("hybrid media transport keeps space and punctuation in both scopes", () => {
  for (const [action, key, code] of [
    ["play", "SPACE", Qt.Key_Space],
    ["previous", ",", Qt.Key_Comma],
    ["next", ".", Qt.Key_Period],
  ]) {
    for (const suffix of ["", "Compact"]) {
      const name = "MediaTransport." + action + suffix;
      assert.equal(f.hint(registry, name), key);
      assert.equal(f.matchesHint(registry, name, code, 0, Qt), true);
      assert.equal(
        f.matchesHint(registry, name, code, Qt.ShiftModifier, Qt),
        false,
      );
    }
  }
  const changed = {
    ...registry,
    overrides: { controls: { Comma: "G" }, media: { Period: "T" } },
  };
  assert.equal(f.hint(changed, "MediaTransport.previousCompact"), "G");
  assert.equal(
    f.matchesHint(changed, "MediaTransport.previousCompact", 71, 0, Qt),
    true,
  );
  assert.equal(f.hint(changed, "MediaTransport.next"), "T");
  assert.equal(f.matchesHint(changed, "MediaTransport.next", 84, 0, Qt), true);
  assert.equal(
    f.matchesHint(
      registry,
      "MediaContent.longer",
      Qt.Key_Plus,
      Qt.ShiftModifier,
      Qt,
    ),
    true,
  );
  assert.equal(
    f.matchesHint(
      registry,
      "MediaContent.longer",
      Qt.Key_Equal,
      Qt.ShiftModifier,
      Qt,
    ),
    true,
  );
  assert.equal(
    f.matchesHint(registry, "MediaContent.shorter", Qt.Key_Minus, 0, Qt),
    true,
  );
});
