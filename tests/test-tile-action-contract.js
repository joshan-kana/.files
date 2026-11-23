const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = name => fs.readFileSync(path.join(shell, "qml", name + ".qml"), "utf8");
const keymap = fs.readFileSync(path.join(shell, "keybindings.nix"), "utf8");

test("opposite action corners are independently accessible and morph-safe", () => {
  const hint = qml("TileKeyHint");
  const secondary = qml("TileCornerAction");
  assert.match(hint, /property bool primary: false/);
  assert.match(hint, /left: primary \? parent\.left : undefined/);
  assert.match(hint, /right: primary \? undefined : parent\.right/);
  assert.match(hint, /circleInset/);
  assert.match(hint, /Behavior on animatedInset/);
  assert.match(secondary, /anchors \{[\s\S]*?top: parent\.top[\s\S]*?right: parent\.right/);
  assert.match(secondary, /Math\.max\(36,/);
  assert.match(secondary, /Accessible\.role: Accessible\.Button/);
  assert.match(secondary, /Accessible\.onPressAction: action\.activated\(\)/);
  assert.match(secondary, /onActivated: action\.activated\(\)/);
  assert.match(secondary, /shortcut: action\.shortcut/);
});

test("every common Controls tile keeps its primary corner when focused", () => {
  for (const [name, action] of [
    ["QuickSettingChip", "chip.shortcut"],
    ["OpacitySetting", "setting.shortcut"],
    ["AdjustableSetting", "setting.toggleShortcut"],
    ["ConnectivityTile", "tile.shortcut"],
  ]) {
    const src = qml(name);
    assert.match(src, /TileKeyHint \{[\s\S]*?primary: true/);
    assert.ok(src.includes("shortcut: " + action), name);
    assert.match(src, /TileCornerAction \{[\s\S]*?onActivated:/);
    assert.doesNotMatch(src, /shortcut: setting\.keyboardSelected \?/);
  }
});

test("tile click, nested detail click and slider drag use distinct handlers", () => {
  const controls = qml("SystemContent");
  assert.match(qml("OpacitySetting"), /onActivated: setting\.toggleRequested\(\)/);
  assert.match(qml("OpacitySetting"), /onActivated: setting\.detailRequested\(\)/);
  assert.match(qml("OpacitySetting"), /onInteractionStarted: \{/);
  assert.match(qml("QuickSettingChip"), /onActivated: chip\.activated\(\)/);
  assert.match(qml("QuickSettingChip"), /onActivated: chip\.detailsRequested\(\)/);
  assert.match(qml("ConnectivityTile"), /onActivated: tile\.activated\(\)/);
  assert.match(qml("ConnectivityTile"), /onActivated: tile\.detailsRequested\(\)/);
  assert.match(controls, /onDetailsRequested: root\.openNetwork\(\)/);
  assert.match(controls, /onDetailsRequested: root\.openBluetooth\(\)/);
  assert.match(controls, /onDetailRequested: root\.openVhs\(\)/);
});

test("primary and detail keyboard actions dispatch directly without prior selection", () => {
  const controls = qml("SystemContent");
  const actions = [
    "SystemContent.vhsToggle",
    "SystemContent.vhsTune",
    "SystemContent.network",
    "SystemContent.networkDetails",
    "SystemContent.bluetooth",
    "SystemContent.bluetoothDetails",
  ];
  for (const action of actions)
    assert.ok(controls.includes('shellMatchesHint("' + action + '", event.key, event.modifiers)'), action);
  assert.match(controls, /shortcut: root\.runtime\.shellHint\("SystemContent\.vhsToggle"\)/);
  assert.match(controls, /detailShortcut: root\.runtime\.shellHint\("SystemContent\.vhsTune"\)/);
  assert.match(controls, /detailShortcut: root\.runtime\.shellHint\("SystemContent\.networkDetails"\)/);
  assert.match(controls, /detailShortcut: root\.runtime\.shellHint\("SystemContent\.bluetoothDetails"\)/);
  for (const [action, key] of [
    ["vhsToggle","ALT+V"], ["vhsTune","SHIFT+V"],
    ["networkDetails","ALT+F"], ["bluetoothDetails","ALT+G"],
    ["network","F"], ["bluetooth","G"], ["powerProfile","V"],
  ])
    assert.ok(keymap.includes('"SystemContent.' + action + '" = "' + key + '"'), action);
});

test("Session QWE/ASD still uses the positional physical keymap", () => {
  const session = qml("SessionPanel");
  const button = qml("SessionActionButton");
  for (const [action, letter] of [
    ["lock","Q"], ["suspend","W"], ["logout","E"],
    ["reboot","A"], ["shutdown","S"], ["restoreWindows","D"],
  ]) {
    assert.ok(session.includes('binding: "SessionPanel.' + action + '"'), action);
    assert.ok(keymap.includes('"SessionPanel.' + action + '" = "' + letter + '"'), action);
  }
  assert.match(button, /TileKeyHint \{[\s\S]*?primary: true/);
  assert.match(session, /entries\.findIndex\(entry => runtime\.shellMatchesHint\(entry\.binding, key, modifiers\)\)/);
});
