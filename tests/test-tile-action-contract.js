const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = (name) =>
  fs.readFileSync(path.join(shell, "qml", name + ".qml"), "utf8");
const keymap = fs.readFileSync(path.join(shell, "keybindings.nix"), "utf8");

test("opposite action corners are independently accessible and morph-safe", () => {
  const hint = qml("TileKeyHint");
  const secondary = qml("TileCornerAction");
  assert.match(hint, /property bool primary: false/);
  assert.match(hint, /left: primary \? parent\.left : undefined/);
  assert.match(hint, /right: primary \? undefined : parent\.right/);
  assert.match(hint, /circleInset/);
  assert.match(hint, /Behavior on animatedInset/);
  assert.match(
    secondary,
    /anchors \{[\s\S]*?top: parent\.top[\s\S]*?right: parent\.right/,
  );
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
    if (["QuickSettingChip", "ConnectivityTile"].includes(name)) {
      assert.doesNotMatch(src, /TileCornerAction \{/);
      assert.match(
        src,
        /TileKeyHint \{[\s\S]*?shortcut: (?:chip|tile)\.detailShortcut/,
      );
      assert.match(
        src,
        /TileQuickAction \{[\s\S]*?hint: (?:primaryHint|shortcutHint)/,
      );
    } else {
      assert.match(src, /TileCornerAction \{[\s\S]*?onActivated:/);
    }
    assert.doesNotMatch(src, /shortcut: setting\.keyboardSelected \?/);
  }
});

test("tile click, nested detail click and slider drag use distinct handlers", () => {
  const controls = qml("SystemContent");
  assert.match(
    qml("OpacitySetting"),
    /onActivated: setting\.toggleRequested\(\)/,
  );
  assert.match(
    qml("OpacitySetting"),
    /onActivated: setting\.detailRequested\(\)/,
  );
  assert.match(qml("OpacitySetting"), /onInteractionStarted: \{/);
  assert.match(qml("QuickSettingChip"), /onActivated: chip\.activated\(\)/);
  assert.match(
    qml("QuickSettingChip"),
    /onActivated: chip\.detailShortcut\.length > 0 \? chip\.detailsRequested\(\)/,
  );
  assert.match(qml("ConnectivityTile"), /onActivated: tile\.activated\(\)/);
  assert.match(
    qml("ConnectivityTile"),
    /onActivated: tile\.detailsRequested\(\)/,
  );
  assert.match(controls, /onDetailsRequested: root\.openNetwork\(\)/);
  assert.match(controls, /onDetailsRequested: root\.openBluetooth\(\)/);
  assert.match(controls, /onDetailsRequested: root\.openVhs\(\)/);
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
    assert.ok(controls.includes('"' + action + '"'), action);
  assert.match(controls, /actionId: "SystemContent\.vhsToggle"/);
  assert.match(controls, /detailActionId: "SystemContent\.vhsTune"/);
  assert.match(controls, /detailActionId: "SystemContent\.networkDetails"/);
  assert.match(controls, /detailActionId: "SystemContent\.bluetoothDetails"/);
  for (const [action, key] of [
    ["vhsToggle", "SHIFT+Z"],
    ["vhsTune", "SHIFT+P"],
    ["networkDetails", "SHIFT+F"],
    ["bluetoothDetails", "SHIFT+G"],
    ["network", "F"],
    ["bluetooth", "G"],
    ["powerProfile", "V"],
  ])
    assert.ok(
      keymap.includes('"SystemContent.' + action + '" = "' + key + '"'),
      action,
    );
});

test("Session QWE/ASD still uses the positional physical keymap", () => {
  const session = qml("SessionPanel");
  const button = qml("SessionActionButton");
  for (const [action, letter] of [
    ["lock", "Q"],
    ["suspend", "W"],
    ["logout", "E"],
    ["reboot", "A"],
    ["shutdown", "S"],
    ["restoreWindows", "D"],
  ]) {
    assert.ok(
      session.includes('binding: "SessionPanel.' + action + '"'),
      action,
    );
    assert.ok(
      keymap.includes('"SessionPanel.' + action + '" = "' + letter + '"'),
      action,
    );
  }
  assert.match(button, /TileKeyHint \{[\s\S]*?primary: true/);
  assert.match(
    session,
    /entries\.findIndex\(entry => runtime\.shellMatchesHint\(entry\.binding, key, modifiers\)\)/,
  );
});

test("detail-only compact cards use the right corner", () => {
  for (const name of ["AudioMixerContent", "ControlsMediaCard"]) {
    const source = qml(name);
    assert.ok(source.includes("TileKeyHint {"));
    assert.ok(source.includes("primary: false"));
  }
});

test("Ethernet-only connectivity keeps status accurate and disables unsupported radio actions", () => {
  const controls = qml("SystemContent");
  const tile = qml("ConnectivityTile");
  for (const sourceLine of [
    "connected: root.system.networkConnected",
    "primaryAvailable: root.system.wifiAvailable",
    "unavailable: root.system.networkDevices.length === 0",
  ])
    assert.ok(controls.includes(sourceLine), sourceLine);
  for (const sourceLine of [
    "property bool primaryAvailable: !unavailable",
    "disabled: false",
    "available: tile.primaryAvailable && !tile.pending",
    "onActivated: tile.detailsRequested()",
  ])
    assert.ok(tile.includes(sourceLine), sourceLine);
});

test("dashboard destination-only tiles advertise a right-corner detail action without a duplicate quick action", () => {
  const controls = qml("SystemContent");
  const tiles = [
    ...controls.matchAll(/QuickSettingChip \{([\s\S]*?)\n {24}\}/g),
  ].map((match) => match[1]);
  assert.equal(tiles.length, 18);
  for (const name of [
    "resources",
    "captures",
    "displays",
    "statusInspection",
  ]) {
    const tile = tiles.find((entry) =>
      entry.includes(`"SystemContent.${name}"`),
    );
    assert.ok(tile, name);
    assert.ok(tile.includes(`detailActionId: "SystemContent.${name}"`));
    assert.doesNotMatch(tile, /\bactionId:|onActivated:/);
    assert.match(tile, /onDetailsRequested: root\.open/);
  }
  const reset = tiles.find((entry) => entry.includes('"SystemContent.reset"'));
  assert.match(reset, /actionId: "SystemContent.reset"/);
  assert.doesNotMatch(reset, /detailActionId:/);
  const chip = qml("QuickSettingChip");
  assert.match(
    chip,
    /shortcut: chip.detailShortcut.length > 0 \? chip.shortcut : ""/,
  );
});
