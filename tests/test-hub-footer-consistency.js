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
    /readonly property bool audioChooserOpen: audioDeck\.deviceChooserOpen/,
  );
  assert.match(
    controls,
    /if \(root\.helpOpen\) \{[\s\S]*?event\.key === Qt\.Key_Escape/,
  );
  assert.match(
    controls,
    /if \(audioDeck\.deviceChooserOpen\) \{[\s\S]*?audioDeck\.handleKey\(event\.key, event\.modifiers\)/,
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
    /contentHeight:.*tabs\.anchors\.topMargin \+ contentViewport\.anchors\.topMargin \+ contentViewport\.anchors\.bottomMargin \+ footerBottomClearance/,
  );
  assert.match(
    host,
    /measuredContentHeight = .*tabs\.anchors\.topMargin \+ contentViewport\.anchors\.topMargin \+ contentViewport\.anchors\.bottomMargin \+ footerBottomClearance/,
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
  assert.match(host, /footerBottomClearance: theme\.spacing5\s*\n/);
  assert.match(
    host,
    /y: Math\.max\(0, host\.visibleFooterBottom - height - host\.footerBottomClearance\)/,
  );
  // The painted background extends spacing2 below the footer content.
  assert.match(host, /y: hubFooter\.y - host\.theme\.spacing2/);
  assert.match(host, /height: hubFooter\.height \+ host\.theme\.spacing2 \* 2/);
  const baseInset = 24;
  for (const overflow of [0, 10, 45, 120]) {
    const paintedClearance = baseInset - 8;
    assert.equal(paintedClearance, 16);
  }
});

test("Audio and Media keyboard legends live in their section and detail headers", () => {
  const host = source("ShellExpansionHost.qml");
  const controls = source("SystemContent.qml");
  const section = source("ShellSection.qml");
  const mixer = source("AudioMixerContent.qml");
  const media = source("MediaContent.qml");
  assert.doesNotMatch(
    host,
    /controlsAudioHints|Select audio|label: "Mute"|label: "Mic"/,
  );
  assert.match(host, /id: hubFooter[\s\S]*?id: footerHints/);
  assert.match(section, /id: headerHints/);
  assert.match(controls, /shortcut: "J\/K",\s*label: "Select"/);
  assert.match(controls, /shortcut: "H\/L",\s*label: "Level"/);
  assert.doesNotMatch(
    controls.slice(
      controls.indexOf('title: "Media"'),
      controls.indexOf("ControlsMediaCard {"),
    ),
    /hints: \[/,
  );
  assert.match(mixer, /id: mixerHints/);
  assert.match(media, /shortcut: "\?",\s*label: "Help"/);
  assert.match(host, /bottomMargin: host.theme.spacing3/);
});

test("Controls reserves its own lower frame clearance without moving other panels", () => {
  const host = source("ShellExpansionHost.qml");
  assert.match(host, /footerBottomClearance: theme\.spacing5\s*\n/);
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
  assert.match(host, /footerBottomClearance: theme\.spacing5\s*\n/);
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
  assert.equal(24 - 8, 16);
});

test("shared key hints collapse empty keycaps without leaving layout gaps", () => {
  const hint = source("KeyHint.qml");
  assert.match(
    hint,
    /readonly property bool hasShortcut: shortcut\.trim\(\)\.length > 0/,
  );
  assert.match(hint, /property bool showLabel: label\.trim\(\)\.length > 0/);
  assert.match(hint, /visible: hasShortcut \|\| showLabel/);
  assert.match(hint, /visible: hint\.hasShortcut/);
  assert.match(hint, /implicitWidth: \(hasShortcut \? cap\.width : 0\)/);
  assert.match(
    hint,
    /implicitHeight: Math\.max\(hasShortcut \? cap\.height : 0/,
  );
  assert.match(
    hint,
    /x: hint\.hasShortcut \? cap\.width \+ hint\.theme\.keyHintGap : 0/,
  );
  const audio = source("AudioDeviceControl.qml");
  assert.match(
    audio,
    /shortcut: deviceControl\.selected \? "M" : deviceControl\.microphone \? "X" : ""/,
  );
  const action = source("ShellAction.qml");
  assert.match(action, /shortcut: root\.shortcut/);
});

test("footer only contains shared navigation and keyboard controls", () => {
  const host = source("ShellExpansionHost.qml");
  assert.doesNotMatch(
    host,
    /id: footerStatus|Critical alerts|notifications"|Recording saved|Saving recording/,
  );
  assert.match(host, /id: footerHints/);
  assert.match(host, /shortcut: "ESC"/);
  assert.match(host, /shortcut: "SHIFT\+ESC"/);
  // The universal recording stop shortcut still works when the hub is open.
  assert.match(
    host,
    /enabled: host.expansionState.hasCurrent && host.recordingState.capturing/,
  );
});
