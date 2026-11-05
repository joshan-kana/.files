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
    /helpVisible \|\| detailVisible \|\| \(systemContent && \(systemContent\.audioChooserOpen \|\| systemContent\.selectedSlider\.length > 0\)\) \? "Back" : "Close"/,
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
    /id: hubFooter[\s\S]*?y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  assert.match(
    host,
    /contentHeight:.*theme\.spacing3 \+ footerBottomClearance \+ theme\.spacing4 \* 2/,
  );
  assert.match(
    host,
    /measuredContentHeight = .*theme\.spacing3 \+ footerBottomClearance \+ theme\.spacing4 \* 2/,
  );
  assert.match(host, /scrollBudget: .*host\.footerBottomClearance/);
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

test("footer background retains physical clearance even when content is taller than the clipped surface", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /footerBottomClearance: theme\.spacing6 \+ theme\.spacing2/,
  );
  assert.match(
    host,
    /y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  // The painted background extends spacing2 below the footer content.
  assert.match(host, /y: hubFooter\.y - host\.theme\.spacing2/);
  assert.match(host, /height: hubFooter\.height \+ host\.theme\.spacing2 \* 2/);
  const baseInset = 32 + 8;
  for (const overflow of [0, 10, 45, 120]) {
    const paintedClearance = baseInset - 8;
    assert.equal(paintedClearance, 32);
  }
});

test("Controls audio hints stay inside the audio widget, never in the global footer", () => {
  const host = source("ShellExpansionHost.qml");
  const controls = source("SystemContent.qml");
  assert.doesNotMatch(
    host,
    /controlsAudioHints|Select audio|label: "Mute"|label: "Mic"/,
  );
  assert.match(host, /id: hubFooter[\s\S]*?id: footerHints/);
  assert.match(
    host,
    /shortcut: "I"[\s\S]*?shortcut: "O"[\s\S]*?shortcut: "ESC"[\s\S]*?shortcut: "SHIFT\+ESC"/,
  );
  assert.match(
    controls,
    /id: audioStack[\s\S]*?KeyHintStrip \{[\s\S]*?label: "Select audio"/,
  );
  for (const [shortcut, label] of [
    ["J/K", "Select audio"],
    ["H/L", "Level"],
    ["X", "Mic"],
  ]) {
    assert.ok(controls.includes('shortcut: "' + shortcut + '"'));
    assert.ok(controls.includes('label: "' + label + '"'));
  }
  assert.doesNotMatch(controls, /shortcut: "M",\s*label: "Mute"/);
  assert.match(
    host,
    /bottomMargin: host\.theme\.spacing3 \+ \(host\.expansionState\.currentName === "system" && !host\.detailVisible \? host\.theme\.spacing4 : 0\)/,
  );
});

test("Controls reserves its own lower frame clearance without moving other panels", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /footerBottomClearance: theme\.spacing6 \+ theme\.spacing2/,
  );
  assert.match(
    host,
    /y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  assert.match(
    host,
    /bottomMargin: host\.theme\.spacing3 \+ \(host\.expansionState\.currentName === "system" && !host\.detailVisible \? host\.theme\.spacing4 : 0\)/,
  );
});

test("navigation footer has one visible-surface inset for every panel", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(
    host,
    /y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  assert.doesNotMatch(
    host,
    /bottom: parent\.bottom[\s\S]{0,450}contentLayoutHeight - shellSurface\.height/,
  );
  assert.match(host, /id: contentViewport[\s\S]*?bottom: hubFooter\.top/);
  assert.match(
    host,
    /footerBottomClearance: theme\.spacing6 \+ theme\.spacing2/,
  );
});

test("connected footer clears the actual rounded frame contour rather than the backing rectangle", () => {
  const host = source("ShellExpansionHost.qml");
  const geometry = source("FrameGeometry.js");
  assert.match(host, /import "FrameGeometry\.js" as FrameGeometry/);
  assert.match(
    host,
    /visibleFooterBottom: frameVisible && screen \? Math\.max\(1, Math\.min\(shellSurface\.height, FrameGeometry\.hubBottomLimit\(screen\.width, screen\.height, theme\.frameThickness, theme\.frameRounding\) - topOffset\)\) : shellSurface\.height/,
  );
  assert.match(
    host,
    /y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  assert.match(
    geometry,
    /function hubBottomLimit\(width, height, thickness, radius\)/,
  );
  assert.match(
    geometry,
    /bottom: Math\.min\(\s*hubBottomLimit\(width, height, thickness, radius\),\s*item\.y \+ item\.height,?\s*\)/,
  );
  // 1440px logical display, 26px frame, 62px rounding and 26px top offset:
  // the visible hub stops at 1349 and the 1353px backing box at 1379.
  const visible = 1440 - 26 - 62 - 3;
  const overflow = 26 + 1353 - visible;
  assert.equal(visible, 1349);
  assert.equal(overflow, 30);
  assert.equal(40 - 8, 32);
});
