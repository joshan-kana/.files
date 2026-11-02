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
    /const fraction = Math\.min\(width \/ Math\.max\(1, host\.contentWidth\), height \/ Math\.max\(1, host\.contentHeight\)\)/,
  );
  assert.match(qml, /\(fraction - 0\.18\) \/ 0\.72/);
  for (const id of ["tabs", "hubFooter", "contentViewport"])
    assert.match(
      qml,
      new RegExp(`id: ${id}\\s+opacity: shellSurface\\.contentReveal`),
    );
});

test("frameless closing keeps the panel until the contraction completes", () => {
  assert.match(
    qml,
    /opacity: host\.expansionState\.hasCurrent \|\| host\.closing \? 1 : 0/,
  );
  assert.match(qml, /closeTimer\.restart\(\)/);
  assert.match(qml, /Behavior on width/);
  assert.match(qml, /Behavior on height/);
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
