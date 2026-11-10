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

test("theme progress has one status owner and an untruncated cancel action", () => {
  const source = qml("ThemePanel.qml");
  const footer = source.slice(source.indexOf("id: footer"));
  assert.match(source, /preparing: "PREPARING"/);
  assert.match(source, /building: "BUILDING"/);
  assert.match(source, /activating: "APPLYING"/);
  const statusRow = footer.indexOf(
    "Row {",
    footer.indexOf("id: cancelLabelMetrics"),
  );
  const statusLabel = footer.indexOf("id: operationStatus", statusRow);
  const cancelControl = footer.indexOf("id: cancelButton", statusRow);
  assert.ok(
    statusRow >= 0 && statusLabel > statusRow && cancelControl > statusLabel,
  );
  assert.match(
    footer,
    /visible: panel\.statusText\.length > 0 \|\| panel\.operationRunning/,
  );
  assert.match(footer, /text: panel\.statusText/);
  assert.match(footer, /font\.pixelSize: panel\.theme\.fontKeyHint/);
  assert.match(footer, /wrapMode: Text\.WrapAtWordBoundaryOrAnywhere/);
  assert.match(
    footer,
    /width: Math\.max\(1, parent\.width - \(cancelButton\.visible/,
  );
  assert.doesNotMatch(footer, /horizontalAlignment: Text\.AlignRight/);
  assert.doesNotMatch(footer, /font\.pixelSize: panel\.theme\.fontSize\(8\)/);
  assert.equal((footer.match(/text: panel\.statusText/g) || []).length, 1);
  assert.doesNotMatch(footer, /panel\.operationPhase\.toUpperCase\(\)/);
  assert.match(footer, /id: cancelLabelMetrics/);
  assert.match(
    footer,
    /width: Math\.max\(180, cancelLabelMetrics\.advanceWidth/,
  );
  assert.match(footer, /title: "Cancel build"/);
  assert.match(footer, /icon: "󰜺"/);
  assert.match(
    footer,
    /visible: panel\.operationRunning && \(panel\.operationPhase === "building" \|\| panel\.operationPhase === "preparing"\)/,
  );
  assert.doesNotMatch(footer, /title:.*"Activating"/);
});

test("Theme search uses filtered gallery items and the shared search field", () => {
  const theme = qml("ThemePanel.qml");
  const controls = qml("SystemContent.qml");
  assert.match(theme, /SearchFieldSurface \{/);
  assert.match(theme, /id: searchField/);
  assert.match(theme, /text: "\/ {2}Search themes"/);
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
