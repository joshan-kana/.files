const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const rate = vm.runInNewContext(read("MediaSelection.js") + "\nadjustedRate");

test("MPRIS rate respects advertised bounds and never writes zero", () => {
  assert.equal(rate(1, 0.5, 2, 0.25), 1.25);
  assert.equal(rate(1.9, 0.5, 2, 0.25), 2);
  assert.equal(rate(0.5, 0.5, 2, -0.25), 0.5);
  assert.equal(rate(0.25, -2, 2, -0.25), -0.25);
  assert.equal(rate(-0.25, -2, 2, 0.25), 0.25);
  assert.equal(rate(0.25, 0, 2, -0.25), 0.25);
  assert.equal(rate(1, 1, 1, 0.25), 1);
});
test("opening a player follows native CanRaise and shared key-down action", () => {
  assert.match(
    read("MediaState.qml"),
    /canRaise: available && player.canRaise/,
  );
  assert.match(read("MediaState.qml"), /if \(canRaise\)\s*player.raise\(\)/);
  const content = read("MediaContent.qml");
  assert.match(content, /visible: content.media.canRaise/);
  assert.match(content, /if \(!event.isAutoRepeat\)\s*raiseAction.trigger\(\)/);
});
