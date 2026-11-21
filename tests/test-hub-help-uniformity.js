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
  assert.match(tabs, /shortcut: root\.runtime\.shellHint\("HubTabs.help"\)/);
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
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.helpOpen"\)[\s\S]*?onActivated: host\.toggleHelp\(\)/,
  );
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.helpClose"\)[\s\S]*?onActivated: host\.otherHelpOpen = false/,
  );
  assert.match(host, /enabled: !host\.otherHelpOpen/);
  assert.match(host, /onCurrentComponentChanged: \{\s*otherHelpOpen = false;/);
  assert.match(host, /else\s+host\.otherHelpOpen = false;/);
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.helpDown"\)[\s\S]*?scopedHelp\.scrollHints\(1\)/,
  );
  assert.match(
    host,
    /sequence: host\.runtime\.shellSequence\("ShellExpansionHost.helpUp"\)[\s\S]*?scopedHelp\.scrollHints\(-1\)/,
  );
});

test("help dims the entire hub while keeping shared header controls and its own scrolling", () => {
  const host = qml("ShellExpansionHost.qml");
  const help = qml("WidgetHelp.qml");
  const overlay = host.slice(
    host.indexOf("        Item {\n            z: 200"),
    host.indexOf(
      "        LoadingOutline {",
      host.indexOf("        Item {\n            z: 200"),
    ),
  );
  assert.match(overlay, /anchors\.fill: parent/);
  assert.match(overlay, /contentArea: contentViewport/);
  assert.match(host, /HubTabs \{[\s\S]*?z: 250/);
  assert.match(overlay, /WidgetHelp \{[\s\S]*?anchors\.fill: parent/);
  assert.match(
    help,
    /height: Math\.min\(\(help\.contentArea \? help\.contentArea\.height : parent\.height\) - theme\.spacing5 \* 2/,
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
  for (const [action, amount] of [
    ["helpDown", 1],
    ["helpArrowDown", 1],
    ["helpUp", -1],
    ["helpArrowUp", -1],
    ["helpPageDown", 4],
    ["helpPgDown", 4],
    ["helpPageUp", -4],
    ["helpPgUp", -4],
  ]) {
    const pattern = new RegExp(
      'sequence: host\\.runtime\\.shellSequence\\("ShellExpansionHost\\.' +
        action +
        '"\\)[\\s\\S]*?enabled: host\\.otherHelpOpen[\\s\\S]*?onActivated: scopedHelp\\.scrollHints\\(' +
        amount +
        "\\)",
    );
    assert.match(host, pattern, action + " should scroll other Help views");
  }

  // Controls and Now Playing retain their focused keyboard handlers.
  for (const page of [system, media]) {
    assert.match(
      page,
      /shellKeyCode\("(?:controls|media)", "J"\) \|\| event\.key === \w+\.runtime\.shellKeyCode\("(?:controls|media)", "Down"\)/,
    );
    assert.match(
      page,
      /shellKeyCode\("(?:controls|media)", "K"\) \|\| event\.key === \w+\.runtime\.shellKeyCode\("(?:controls|media)", "Up"\)/,
    );
    assert.match(
      page,
      /shellKeyCode\("(?:controls|media)", "D"\) \|\| event\.key === \w+\.runtime\.shellKeyCode\("(?:controls|media)", "PageDown"\)/,
    );
    assert.match(
      page,
      /shellKeyCode\("(?:controls|media)", "U"\) \|\| event\.key === \w+\.runtime\.shellKeyCode\("(?:controls|media)", "PageUp"\)/,
    );
  }

  assert.match(
    help,
    /hintsViewport\.contentY = Math\.max\(0, Math\.min\(limit,/,
  );
  assert.match(
    help,
    /onOpenChanged: \{\s*if \(open\)\s*hintsViewport\.contentY = 0;/,
  );
  assert.match(
    help,
    /keyboardScroll \? help\.runtime\.shellHint\("ShellExpansionHost\.helpDown"\)/,
  );
});
