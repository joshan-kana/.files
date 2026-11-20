const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const dir = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qmlDir = path.join(dir, "qml");
const source = fs.readFileSync(path.join(dir, "keybindings.nix"), "utf8");
const baseText = source.split("base = {")[1].split("  };")[0];
const base = Object.fromEntries(
  [...baseText.matchAll(/^\s*(?:"(\d)"|([A-Za-z]\w*))\s*=\s*"([^"]+)";/gm)].map(
    (m) => [m[1] || m[2], m[3]],
  ),
);
const hints = Object.fromEntries(
  [
    ...source.matchAll(
      /"([^"\n]+)"\s*=\s*\{\s*scope\s*=\s*"([^"]+)";\s*template\s*=\s*"([^"]*)";(?:\s*literal\s*=\s*true;)?\s*\};/gm,
    ),
  ].map((m) => [m[1], { scope: m[2], template: m[3] }]),
);
const actionAssignments = Object.fromEntries(
  [...source.matchAll(/^ {4}"(SystemContent\.[^"]+)" = "([^"]+)";$/gm)].map(
    (m) => [m[1], m[2]],
  ),
);
const registry = { base, overrides: {}, actions: actionAssignments, hints };
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
    "\n({assigned,keyCode,modifier,hint,sequence,matchesHint,numberIndex,numberHint})",
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
  assert.equal(f.hint(changed, "ThemePanel.columns"), "M/L");
  assert.equal(f.keyCode(changed, "calendar", "H", Qt), 72);
  assert.equal(f.hint(changed, "CalendarContent.days"), "H/L");
  assert.equal(f.matchesHint(changed, "SessionPanel.lock", 90, 0, Qt), true);
  assert.equal(f.matchesHint(changed, "SessionPanel.lock", 81, 0, Qt), false);
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

test("shell-local and compositor-global shortcuts have distinct owners", () => {
  const nix = fs.readFileSync(path.join(dir, "default.nix"), "utf8");
  const runtime = fs.readFileSync(
    path.join(qmlDir, "RuntimeConfig.qml"),
    "utf8",
  );
  const global = fs.readFileSync(path.join(dir, "../keybindings.nix"), "utf8");
  assert.match(nix, /shellBindings = import \.\/keybindings\.nix/);
  assert.match(nix, /keybindings = import \.\.\/keybindings\.nix/);
  assert.match(
    runtime,
    /ShellKeybindings\.keyCode\(shellBindings, scope, slot, Qt\)/,
  );
  assert.match(runtime, /ShellKeybindings\.hint\(shellBindings, action\)/);
  assert.match(global, /id = "status\.inspect"/);
});

test("numbered actions use the assigned key for each index, not a contiguous keycode range", () => {
  assert.equal(f.numberIndex(registry, "activity", 49, 9, Qt), 0);
  assert.equal(f.numberIndex(registry, "activity", 57, 9, Qt), 8);
  const remapped = { ...registry, overrides: { activity: { 1: "9", 9: "1" } } };
  assert.equal(f.numberIndex(remapped, "activity", 49, 9, Qt), 8);
  assert.equal(f.numberIndex(remapped, "activity", 57, 9, Qt), 0);
  assert.equal(f.numberHint(remapped, "activity", 0), "9");
  assert.equal(f.numberHint(remapped, "activity", 8), "1");
  for (const name of ["NotificationContent.qml", "OverviewPanel.qml"])
    assert.match(
      fs.readFileSync(path.join(qmlDir, name), "utf8"),
      /shellNumberIndex/,
    );
  assert.match(
    fs.readFileSync(path.join(qmlDir, "NotificationCard.qml"), "utf8"),
    /shellNumberHint/,
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
  for (const action of Object.keys(actionAssignments))
    assert.ok(
      controls.includes(
        `shellMatchesHint("${action}", event.key, event.modifiers)`,
      ),
    );
});
