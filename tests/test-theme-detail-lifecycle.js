const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, `../modules/desktop/hyprland/shell/qml/${name}`),
    "utf8",
  );

test("closed theme details cannot steal focus while the hub is closing", () => {
  const source = qml("ThemePanel.qml");
  const close = source.match(
    /function closeView\(\): void \{([\s\S]*?)\n {4}\}/,
  )?.[1];
  assert.ok(close);
  assert.match(close, /if \(!open\)\s*return/);
  assert.match(close, /open = false/);
  assert.doesNotMatch(close, /keyboardRequested\(/);
});

test("Controls restores detail focus only while engaged", () => {
  const source = qml("SystemContent.qml");
  assert.match(
    source,
    /function applyRequestedView\(\): void \{\s*if \(!engaged\)\s*return;/,
  );
  assert.match(
    source,
    /const leavingDetail = detailsVisible;\s*closeDetails\(\);\s*if \(leavingDetail\)\s*keyboardFocus\.forceActiveFocus\(\)/,
  );
});

test("a stale queued expansion cannot reopen a closing or replaced hub", () => {
  const source = qml("ShellExpansionHost.qml");
  assert.match(source, /property int transitionEpoch: 0/);
  assert.match(source, /const epoch = \+\+host\.transitionEpoch/);
  assert.match(
    source,
    /if \(host\.transitionEpoch === epoch && host\.expansionState\.hasCurrent\)\s*host\.contentExpanded = true/,
  );
});

test("Theme progress uses the shared header status and one cancel owner", () => {
  const source = qml("ThemePanel.qml");
  const shared = qml("PanelStatus.qml");
  const footer = source.slice(source.indexOf("id: footer"));
  assert.match(source, /preparing: "PREPARING"/);
  assert.match(source, /building: "BUILDING"/);
  assert.match(source, /activating: "APPLYING"/);
  assert.match(source, /PanelStatus \{\s*id: operationBanner/);
  assert.match(source, /top: searchSurface\.bottom/);
  assert.match(source, /top: operationBanner\.bottom/);
  assert.match(source, /message: panel\.statusText/);
  assert.match(source, /cancelShortcut: "X"/);
  assert.match(source, /onCancelRequested: panel\.cancelOperation\(\)/);
  assert.doesNotMatch(
    footer,
    /id: operationStatus|id: cancelButton|text: panel\.statusText/,
  );
  assert.match(shared, /readonly property string symbol: phase === "busy"/);
  assert.match(shared, /cancelAction/);
  for (const panel of [
    "WallpaperPanel.qml",
    "NetworkPanel.qml",
    "BluetoothPanel.qml",
    "RecordingLibrary.qml",
  ]) {
    const surface = qml(panel);
    assert.match(surface, /PanelStatus \{\s*id: statusBanner/);
    assert.match(surface, /message: (?:panel|library)\.statusText/);
    assert.doesNotMatch(
      surface.slice(surface.indexOf("id: footer")),
      /text: (?:panel|library)\.statusText/,
    );
  }
});

test("Theme search uses filtered gallery items and the shared search field", () => {
  const theme = qml("ThemePanel.qml");
  const controls = qml("SystemContent.qml");
  assert.match(theme, /SearchFieldSurface \{/);
  assert.match(theme, /id: searchField/);
  assert.match(theme, /text: "Search themes"/);
  assert.match(theme, /function enterSearch\(\): void/);
  assert.match(theme, /function leaveSearch\(\): void/);
  assert.match(theme, /model: panel.filteredThemes/);
  assert.match(theme, /return filteredThemes\[Math.max/);
  assert.match(theme, /searchField.text = ""/);
  assert.match(
    theme,
    /text: panel.themes.length === 0 \? "Loading themes…" : "No matching themes"/,
  );
  assert.match(
    controls,
    /if \(themePanel.open\)[\s\S]*?event.key === Qt.Key_Slash\)[\s\S]*?themePanel.invoke\("enterSearch"\)/,
  );
  const source = theme.match(/readonly property var filteredThemes: (.+)/);
  assert.ok(source);
  const filter = new Function(
    "themes",
    "searchText",
    "return (" + source[1] + ");",
  );
  const themes = [
    { name: "catppuccin-mocha", label: "Catppuccin Mocha" },
    { name: "gruvbox-material", label: "Gruvbox Material" },
    { name: "tokyo-night", label: "Tokyo Night" },
  ];
  assert.deepEqual(
    filter(themes, "GRUV").map((item) => item.name),
    ["gruvbox-material"],
  );
  assert.deepEqual(
    filter(themes, "tokyo-night").map((item) => item.name),
    ["tokyo-night"],
  );
  assert.deepEqual(filter(themes, "nonexistent"), []);
  assert.equal(filter(themes, "").length, themes.length);
});

test("Theme search returns focus to the shared keyboard owner", () => {
  const theme = qml("ThemePanel.qml");
  const controls = qml("SystemContent.qml");
  assert.match(
    theme,
    /event.key === Qt.Key_Escape\)[\s\S]*?panel.leaveSearch\(\)/,
  );
  assert.match(
    theme,
    /Qt.Key_Return \|\| event.key === Qt.Key_Enter\)[\s\S]*?panel.activateSelected\(\);[\s\S]*?panel.leaveSearch\(\)/,
  );
  assert.match(
    theme,
    /function leaveSearch\(\): void \{\s*keyboardRequested\(\);/,
  );
  assert.match(
    controls,
    /ThemePanel \{[\s\S]*?onKeyboardRequested: keyboardFocus.forceActiveFocus\(\)/,
  );
});
