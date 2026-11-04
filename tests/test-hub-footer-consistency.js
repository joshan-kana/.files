const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("shared footer always shows Escape and Shift+Escape, including details", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /model: \(host\.tabShortcutsEnabled \? \[[\s\S]*?\] : \[\]\)\.concat\(\[[\s\S]*?shortcut: "ESC",[\s\S]*?label: host\.escapeHintLabel[\s\S]*?shortcut: "SHIFT\+ESC",[\s\S]*?label: "Close all"/,
  );
  assert.doesNotMatch(
    host,
    /host\.detailVisible \? \[\] : \[[\s\S]*?shortcut: "ESC"/,
  );
  assert.match(
    host,
    /sequence: "Shift\+Esc"[\s\S]*?onActivated: host\.expansionState\.close\(\)/,
  );
});

test("Escape label follows the actual focus owner", () => {
  const host = source("ShellExpansionHost.qml");
  const controls = source("SystemContent.qml");
  assert.match(
    host,
    /escapeHintLabel: systemContent && systemContent\.resetConfirmPending \? "Cancel"/,
  );
  assert.match(
    host,
    /helpVisible \|\| detailVisible \|\| \(systemContent && systemContent\.audioChooserOpen\) \? "Back" : "Close"/,
  );
  assert.match(
    controls,
    /readonly property bool audioChooserOpen: outputQuick\.chooserOpen \|\| inputQuick\.chooserOpen/,
  );
  assert.match(
    controls,
    /if \(root\.helpOpen\) \{[\s\S]*?event\.key === Qt\.Key_Escape/,
  );
  assert.match(
    controls,
    /if \(outputQuick\.chooserOpen \|\| inputQuick\.chooserOpen\) \{[\s\S]*?event\.key === Qt\.Key_Escape/,
  );
});

test("tab hints are only shown when their I/O shortcuts actually work", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /tabShortcutsEnabled: expansionState\.hasCurrent && !detailVisible && !helpVisible && !\(systemContent && \(systemContent\.resetConfirmPending \|\| systemContent\.audioChooserOpen\)\)/,
  );
  assert.equal(
    (host.match(/enabled: host\.tabShortcutsEnabled/g) || []).length,
    2,
  );
  assert.match(host, /model: \(host\.tabShortcutsEnabled \? \[/);
});

test("footer inset and panel height agree for both measured and live geometry", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /id: hubFooter[\s\S]*?bottomMargin: host\.theme\.spacing5/,
  );
  assert.match(
    host,
    /contentHeight:.*theme\.spacing3 \+ theme\.spacing5 \+ theme\.spacing4 \* 2/,
  );
  assert.match(
    host,
    /measuredContentHeight = .*theme\.spacing3 \+ theme\.spacing5 \+ theme\.spacing4 \* 2/,
  );
  assert.match(host, /scrollBudget: .*host\.theme\.spacing5/);
});

test("footer uses the Controls surface material without a second glass layer", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /id: footerSurface[\s\S]*?color: host\.theme\.expressiveSurface/,
  );
  assert.match(
    host,
    /id: footerSurface[\s\S]*?opacity: shellSurface\.contentReveal/,
  );
  assert.match(host, /id: footerHints/);
  assert.match(host, /id: footerScrollHints/);
  assert.doesNotMatch(host, /ShellSurface \{\s*id: footerSurface/);
});

test("keycap material and compact footer presentation use the shared theme", () => {
  const hint = source("KeyHint.qml");
  const host = source("ShellExpansionHost.qml");
  assert.match(hint, /color: hint\.theme\.expressiveSurfaceStrong/);
  assert.match(
    hint,
    /textColor: hint\.emphasized \? hint\.theme\.textStrong : hint\.theme\.text/,
  );
  assert.match(host, /delegate: KeyHint \{[\s\S]*?compact: true/);
  assert.match(source("KeyHintStrip.qml"), /property bool compact: true/);
});

test("local notification and wallpaper panels show their supported Escape action", () => {
  const activity = source("NotificationContent.qml");
  const wallpaper = source("WallpaperPanel.qml");
  assert.match(activity, /shortcut: "ESC",\s*label: "Close"/);
  assert.match(activity, /event\.key === Qt\.Key_Escape/);
  assert.match(wallpaper, /shortcut: "ESC",\s*label: "Back"/);
  assert.match(wallpaper, /event\.key === Qt\.Key_Escape/);
});
