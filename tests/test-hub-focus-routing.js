const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const host = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
  ),
  "utf8",
);
const present = host.slice(
  host.indexOf("function presentComponent(next: Component)"),
  host.indexOf("function onLoaderReady(loader: Loader)"),
);

test("tab changes restore local keyboard focus even before the hub finishes opening", () => {
  assert.match(present, /activeSlot = incoming === contentLoaderA/);
  assert.match(present, /incoming\.sourceComponent = next/);
  assert.match(
    present,
    /if \(expansionState\.hasCurrent && incoming\.item && !themeTerminalActive && !incoming\.item\.activeFocus\)\s+\(incoming\.item as Item\)\.forceActiveFocus\(\);/,
  );
  assert.doesNotMatch(present, /if \(outgoing\)|const outgoing =/);
});

test("tab handoff remains immediate and async loader readiness restores focus", () => {
  assert.doesNotMatch(present, /Qt\.callLater/);
  assert.match(
    host,
    /function onLoaderReady\(loader: Loader\)[\s\S]*?Qt\.callLater\(\(\) => \{[\s\S]*?host\.activeLoader === loader && loader\.item[\s\S]*?forceActiveFocus\(\)/,
  );
  assert.match(host, /onActivated: host\.cycleTab\(-1\)/);
  assert.match(host, /onActivated: host\.cycleTab\(1\)/);
});

test("inactive Home and Weather pages cannot reclaim focus after a tab change", () => {
  for (const [file, owner, sink] of [
    ["CalendarContent.qml", "calendar", "keySink"],
    ["WeatherContent.qml", "panel", "keys"],
  ]) {
    const source = fs.readFileSync(
      path.join(__dirname, "../modules/desktop/hyprland/shell/qml", file),
      "utf8",
    );
    assert.ok(
      source.includes(`if (${owner}.engaged && !${sink}.activeFocus)`),
      `${file} must only refocus while engaged`,
    );
    assert.ok(
      source.includes(`${sink}.forceActiveFocus();`),
      `${file} should still restore its key sink`,
    );
    assert.doesNotMatch(
      source,
      /Qt\.callLater\(\(\) => (?:keySink|keys)\.forceActiveFocus\(\)\);/,
    );
  }
});

test("an active hub recovers focus from the window root without stealing fields", () => {
  const focusWindow = host.slice(
    host.indexOf(
      "target: host.contentItem ? host.contentItem.Window.window : null",
    ),
    host.indexOf("HyprlandFocusGrab {"),
  );
  assert.match(focusWindow, /function onActiveFocusItemChanged\(\): void/);
  assert.match(focusWindow, /window\.activeFocusItem !== window\.contentItem/);
  assert.match(focusWindow, /window\.activeFocusItem === window\.contentItem/);
  assert.match(
    focusWindow,
    /window\.active && window\.activeFocusItem === window\.contentItem && host\.expansionState\.hasCurrent && !host\.themeTerminalActive && host\.loadedContent/,
  );
  assert.match(focusWindow, /host\.loadedContent\.forceActiveFocus\(\)/);
});
