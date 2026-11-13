const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("a single shared question-mark action is visible on every hub page and detail", () => {
  const tabs = qml("HubTabs.qml");
  const host = qml("ShellExpansionHost.qml");
  assert.match(tabs, /signal helpRequested/);
  assert.match(tabs, /shortcut: "\?"/);
  assert.match(tabs, /Accessible\.name: "Keyboard help"/);
  assert.match(tabs, /onActivated: root\.helpRequested\(\)/);
  assert.match(host, /helpOpen: host\.helpVisible/);
  assert.match(host, /onHelpRequested: host\.toggleHelp\(\)/);
  assert.match(
    host,
    /readonly property var helpKeys: systemContent \? systemContent\.helpBindings : mediaContent \? mediaContent\.helpBindings : otherHelpKeys/,
  );
  assert.match(
    host,
    /readonly property string helpCaption:.*Activity controls.*Weather controls.*Home controls/,
  );
  assert.doesNotMatch(
    qml("SystemContent.qml"),
    /id: helpButton|title: "Help \(\?\)"/,
  );
  assert.doesNotMatch(
    qml("MediaContent.qml"),
    /label: "Help"|title: "Help \(\?\)"/,
  );
});

test("contextual help can be opened and dismissed on every hub page without triggering underlying shortcuts", () => {
  const host = qml("ShellExpansionHost.qml");
  assert.match(host, /function toggleHelp\(\): void/);
  assert.match(host, /sequence: "\?"[\s\S]*?onActivated: host\.toggleHelp\(\)/);
  assert.match(
    host,
    /sequence: "Esc"[\s\S]*?onActivated: host\.otherHelpOpen = false/,
  );
  assert.match(host, /enabled: !host\.otherHelpOpen/);
  assert.match(host, /onCurrentComponentChanged: \{\s*otherHelpOpen = false;/);
  assert.match(host, /else\s+host\.otherHelpOpen = false;/);
  assert.match(host, /sequence: "J"[\s\S]*?scopedHelp\.scrollHints\(1\)/);
  assert.match(host, /sequence: "K"[\s\S]*?scopedHelp\.scrollHints\(-1\)/);
});

test("help stays between the shared header and footer, and scrolls in its own viewport", () => {
  const host = qml("ShellExpansionHost.qml");
  const help = qml("WidgetHelp.qml");
  const overlay = host.slice(
    host.indexOf("        Item {\n            z: 200"),
    host.indexOf(
      "        LoadingOutline {",
      host.indexOf("        Item {\n            z: 200"),
    ),
  );
  assert.match(overlay, /top: tabs\.bottom/);
  assert.match(overlay, /bottom: hubFooter\.top/);
  assert.match(overlay, /topMargin: host\.theme\.spacing3/);
  assert.match(overlay, /bottomMargin: host\.theme\.spacing3/);
  assert.doesNotMatch(
    overlay,
    /anchors\.fill: parent[\s\S]*?opacity: shellSurface\.contentReveal/,
  );
  assert.match(overlay, /WidgetHelp \{[\s\S]*?anchors\.fill: parent/);
  assert.match(
    help,
    /height: Math\.min\(parent\.height - theme\.spacing5 \* 2/,
  );
  assert.match(help, /contentHeight: content\.implicitHeight/);
  assert.match(help, /clip: true/);
});

test("keyboard scrolling is available on every contextual Help view", () => {
  const host = qml("ShellExpansionHost.qml");
  const system = qml("SystemContent.qml");
  const media = qml("MediaContent.qml");
  const help = qml("WidgetHelp.qml");

  // Home, Weather and Activity use application shortcuts, which work
  // regardless of the focused card or virtualized page.
  for (const [shortcut, amount] of [
    ["J", 1],
    ["Down", 1],
    ["K", -1],
    ["Up", -1],
    ["D", 4],
    ["PgDown", 4],
    ["U", -4],
    ["PgUp", -4],
  ]) {
    const pattern = new RegExp(
      'sequence: "' +
        shortcut +
        '"[\\s\\S]*?enabled: host\\.otherHelpOpen[\\s\\S]*?onActivated: scopedHelp\\.scrollHints\\(' +
        amount +
        "\\)",
    );
    assert.match(host, pattern, shortcut + " should scroll other Help views");
  }

  // Controls and Now Playing retain their focused keyboard handlers.
  for (const page of [system, media]) {
    assert.match(page, /Qt\.Key_J \|\| event\.key === Qt\.Key_Down/);
    assert.match(page, /Qt\.Key_K \|\| event\.key === Qt\.Key_Up/);
    assert.match(page, /Qt\.Key_D \|\| event\.key === Qt\.Key_PageDown/);
    assert.match(page, /Qt\.Key_U \|\| event\.key === Qt\.Key_PageUp/);
  }

  assert.match(
    help,
    /hintsViewport\.contentY = Math\.max\(0, Math\.min\(limit,/,
  );
  assert.match(
    help,
    /onOpenChanged: \{\s*if \(open\)\s*hintsViewport\.contentY = 0;/,
  );
  assert.match(help, /keyboardScroll \? "J\/K scroll · U\/D page/);
});
