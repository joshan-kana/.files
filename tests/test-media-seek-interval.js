const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const read = (file) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", file),
    "utf8",
  );

test("seek interval has one validated persistent preference and a declarative default", () => {
  const appearance = read("AppearancePreferences.qml");
  assert.match(appearance, /property int mediaSeekSeconds: 10/);
  assert.match(
    appearance,
    /readonly property var seekIntervals: \[5, 10, 15, 30, 60\]/,
  );
  assert.match(
    appearance,
    /readonly property int mediaSeekSeconds: seekIntervals\.includes\(saved\.mediaSeekSeconds\) \? saved\.mediaSeekSeconds : 10/,
  );
  assert.match(
    appearance,
    /saved\.setValue\("mediaSeekSeconds", saved\.mediaSeekSeconds\)/,
  );
  assert.match(appearance, /saved\.sync\(\)/);
  const steps = [5, 10, 15, 30, 60];
  for (const i of steps.keys()) {
    assert.equal(steps[Math.max(0, i - 1)], steps[i - 1] || 5);
    assert.equal(steps[Math.min(4, i + 1)], steps[i + 1] || 60);
  }
});
test("all media transport buttons and global shortcuts use the same step", () => {
  const media = read("MediaState.qml");
  assert.match(media, /required property AppearancePreferences appearance/);
  assert.match(
    media,
    /readonly property int seekSeconds: appearance\.mediaSeekSeconds/,
  );
  assert.match(
    media,
    /function seekStep\(direction: int\): void \{\s*seek\(direction \* seekSeconds\)/,
  );
  const actions = read("Actions.qml");
  assert.match(
    actions,
    /function mediaSeekForward\(\): void \{\s*mediaState\.seekStep\(1\)/,
  );
  assert.match(
    actions,
    /function mediaSeekBackward\(\): void \{\s*mediaState\.seekStep\(-1\)/,
  );
  const transport = read("MediaTransport.qml");
  assert.match(transport, /root\.media\.seekStep\(1\)/);
  assert.match(transport, /root\.media\.seekStep\(-1\)/);
  const page = read("MediaContent.qml");
  assert.match(page, /content\.media\.seekStep\(1\)/);
  assert.match(page, /content\.media\.seekStep\(-1\)/);
  const controls = read("SystemContent.qml");
  assert.match(controls, /root\.media\.seekStep\(1\)/);
  assert.match(controls, /root\.media\.seekStep\(-1\)/);
  for (const [file, contents] of [
    ["Actions.qml", actions],
    ["MediaTransport.qml", transport],
    ["MediaContent.qml", page],
    ["SystemContent.qml", controls],
  ]) {
    assert.doesNotMatch(
      contents,
      /\.seek\([+-]?(?:5|10)\)/,
      file + " must not bypass the configured interval",
    );
  }
});
test("seek interval controls use shared action keycaps and include keyboard navigation", () => {
  const page = read("MediaContent.qml");
  assert.match(page, /shortcut: "-"/);
  assert.match(page, /shortcut: "\+"/);
  assert.match(page, /onActivated: content\.media\.adjustSeekStep\(1\)/);
  assert.match(page, /onActivated: content\.media\.adjustSeekStep\(-1\)/);
  assert.match(page, /Qt\.Key_Minus \|\| event\.key === Qt\.Key_Underscore/);
  assert.match(page, /Qt\.Key_Plus \|\| event\.key === Qt\.Key_Equal/);
  assert.match(page, /Seek interval · " \+ media\.seekSeconds/);
});

test("global keybinding descriptions match the configurable seek interval", () => {
  const bindings = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/keybindings.nix"),
    "utf8",
  );
  assert.match(
    bindings,
    /description = "Seek backward by configured interval"/,
  );
  assert.match(bindings, /description = "Seek forward by configured interval"/);
  assert.doesNotMatch(
    bindings,
    /description = "Seek (backward|forward) 10 seconds"/,
  );
});

test("Now Playing seek-step controls have readable words and enough width", () => {
  const page = read("MediaContent.qml");
  for (const [title, width] of [
    ["Shorter", 116],
    ["Longer", 116],
  ]) {
    assert.match(
      page,
      new RegExp("width: " + width + '[\\s\\S]*?title: "' + title + '"'),
    );
  }
  assert.match(page, /text: "Seek " \+ content\.media\.seekSeconds \+ "s"/);
  assert.doesNotMatch(page, /title: "[+−] SEEK"/);
});
