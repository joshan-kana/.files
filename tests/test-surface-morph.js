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
    /const fraction = Math\.min\(width \/ widthGoal, height \/ heightGoal\)/,
  );
  assert.match(qml, /\(fraction - 0\.68\) \/ 0\.30/);
  for (const id of ["hubFooter", "contentViewport"])
    assert.match(
      qml,
      new RegExp(
        `id: ${id}[\\s\\S]{0,240}?opacity: shellSurface\\.contentReveal`,
      ),
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
    /dockOrigin: qmlAmbientBar\.originFor\(qmlExpansionState\.screen/,
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

test("hub header follows live painted width independently of the destination layout and remains visible across page morphs", () => {
  assert.match(qml, /id: tabs[\s\S]*?opacity: shellSurface\.headerReveal/);
  assert.match(
    qml,
    /x: shellSurface\.x - contentFrame\.x \+ host\.theme\.spacing4/,
  );
  assert.match(
    qml,
    /width: Math\.max\(0, shellSurface\.width - host\.theme\.spacing4 \* 2\)/,
  );
  const reveal = qml.match(
    /readonly property real headerReveal: \{([\s\S]*?)\n {8}\}/,
  )[1];
  assert.match(reveal, /host\.chromeOpacity/);
  assert.doesNotMatch(reveal, /contentWidth|contentHeight|contentLayoutWidth/);
  const tabs = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml/HubTabs.qml"),
    "utf8",
  );
  assert.match(
    tabs,
    /width: Math\.max\(0, parent\.width - backButton\.width - helpButton\.width/,
  );
  assert.match(
    tabs,
    /x: root\.theme\.spacing1 \+ width \* root\.animatedIndex/,
  );
});

test("tab changes retain a complete measurement and never shrink the outgoing content to the next page", () => {
  assert.match(qml, /property size measuredContentSize: Qt.size\(0, 0\)/);
  assert.match(qml, /measuredContentSize = Qt.size\(width, height\)/);
  assert.match(
    qml,
    /target: host.controlsContent\s+property: "dashboardWidthBudget"/,
  );
  assert.match(
    qml,
    /target: host.controlsContent\s+property: "detailWidthLimit"/,
  );
  assert.match(
    qml,
    /contentReveal: host.contentRevealed \? host.chromeOpacity : openingReveal/,
  );
  assert.match(
    qml,
    /onOpeningRevealChanged:[\s\S]*?host.contentRevealed = true/,
  );
  assert.doesNotMatch(
    qml,
    /scale: Math.min\(1, contentViewport.width|incoming.opacity = 0|id: contentEnter/,
  );
  assert.equal(
    [...qml.matchAll(/x: \(contentViewport.width - width\) \/ 2/g)].length,
    5,
  );
  const viewport = qml.slice(
    qml.indexOf("id: contentViewport"),
    qml.indexOf("id: contentLoaderA"),
  );
  assert.match(
    viewport,
    /x: shellSurface\.x - contentFrame\.x \+ host\.theme\.spacing4/,
  );
  assert.match(
    viewport,
    /width: Math\.max\(0, shellSurface\.width - host\.theme\.spacing4 \* 2\)/,
  );
  assert.match(viewport, /top: tabs\.bottom\s+bottom: hubFooter\.top/);
  assert.match(viewport, /clip: true/);
  assert.doesNotMatch(
    viewport,
    /clip: !|left: parent\.left|right: parent\.right/,
  );
  const controls = fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/SystemContent.qml",
    ),
    "utf8",
  );
  assert.match(controls, /geometryReady: !requestedViewTimer.running/);
  assert.match(
    controls,
    /requestedView.length > 0 && requestedView === presentedDetail/,
  );
  assert.match(
    controls,
    /onVisibleChanged: if \(!visible && !engaged\)\s*closeDetails\(\)/,
  );
});
