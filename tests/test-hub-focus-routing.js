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

test("deferred keyboard recovery is guarded against stale tabs and focused editors", () => {
  assert.match(
    present,
    /Qt\.callLater\(\(\) => \{[\s\S]*?host\.expansionState\.hasCurrent && !host\.themeTerminalActive && host\.activeLoader === incoming && host\.currentComponent === next && incoming\.item && !incoming\.item\.activeFocus[\s\S]*?forceActiveFocus\(\)/,
  );
  assert.match(
    host,
    /function onLoaderReady\(loader: Loader\)[\s\S]*?host\.activeLoader === loader && loader\.item[\s\S]*?forceActiveFocus\(\)/,
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
