const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/ShellExpansionHost.qml",
  ),
  "utf8",
);

test("all hub views reveal progressively while geometry expands", () => {
  assert.match(
    qml,
    /property real chromeOpacity: expansionState\.hasCurrent && contentExpanded \? 1 : 0/,
  );
  assert.match(
    qml,
    /const fraction = Math\.min\(width \/ Math\.max\(1, host\.closing \? host\.closeLayoutWidth : host\.contentWidth\), height \/ Math\.max\(1, host\.closing \? host\.closeLayoutHeight : host\.contentHeight\)\)/,
  );
  assert.match(qml, /\(fraction - 0\.68\) \/ 0\.30/);
  for (const id of ["tabs", "hubFooter", "contentViewport"])
    assert.match(
      qml,
      new RegExp(`id: ${id}\\s+opacity: shellSurface\\.contentReveal`),
    );
});

test("all visual modes close to one stable terminal shape", () => {
  assert.match(qml, /readonly property real compactWidth: barVisible \?/);
  assert.match(qml, /readonly property real compactHeight: barVisible \?/);
  assert.match(qml, /property var dockOrigin:/);
  assert.match(qml, /host\.closeWidth = Math\.max\(1, host\.compactWidth\)/);
  assert.match(
    qml,
    /host\.closeLayoutWidth = shellSurface\.contentLayoutWidth/,
  );
  assert.match(
    qml,
    /host\.closeLayoutHeight = shellSurface\.contentLayoutHeight/,
  );
  assert.match(
    qml,
    /closing \? closeWidth : barVisible \? Math\.max\(1, expansionState\.originWidth\) : compactWidth/,
  );
  assert.match(
    qml,
    /closing \? closeHeight : barVisible \? Math\.max\(1, expansionState\.originHeight\) : compactHeight/,
  );
  assert.match(qml, /host\.finishCloseIfSettled\(\)/);
  assert.match(qml, /const reversingClose = host\.closing/);
  assert.match(qml, /host\.contentExpanded = reversingClose/);
  assert.match(qml, /Behavior on width/);
  assert.match(qml, /Behavior on height/);
});

test("connected bar returns the actual clock island only near completion", () => {
  assert.match(
    qml,
    /const progress = Math\.min\(widthProgress, heightProgress\)/,
  );
  assert.match(qml, /\(progress - 0\.65\) \/ 0\.35/);
  const shell = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/shell.qml"),
    "utf8",
  );
  assert.match(
    shell,
    /dockOrigin: ambientBar\.originFor\(expansionState\.screen/,
  );
  assert.match(shell, /expansionHost\.clockReveal < 0\.05/);
});

test("help opacity is owned by the help widget beneath the shared container", () => {
  assert.match(
    qml,
    /Item\s*\{[\s\S]*?opacity: shellSurface\.contentReveal\s+WidgetHelp\s*\{/,
  );
  assert.doesNotMatch(
    qml,
    /id: scopedHelp\s+opacity: shellSurface\.contentReveal/,
  );
});

test("host flickable never steals hover/scroll gestures from nested views", () => {
  assert.match(
    qml,
    /interactive: contentHeight > height && !host\.detailVisible && host\.expansionState\.currentName !== "activity" && host\.expansionState\.currentName !== "calendar"/,
  );
  assert.match(
    qml,
    /readonly property bool hostPageShortcutsEnabled: expansionState\.hasCurrent/,
  );
});
