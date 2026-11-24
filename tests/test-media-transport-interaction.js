const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("connected media controls keep fixed layout slots and stable identities through player updates", () => {
  const transport = qml("MediaTransport.qml");
  const model = transport.slice(
    transport.indexOf("readonly property var actions:"),
    transport.indexOf("onSimpleChanged:"),
  );
  assert.doesNotMatch(model, /media\.|shellHint/);
  assert.match(transport, /model: root.actions/);
  assert.match(transport, /connectedGroup: true/);
  assert.match(
    transport,
    /neighborPressed: root.pressedIndex >= 0 && Math.abs\(root.pressedIndex - index\) === 1/,
  );
  assert.match(transport, /onVisualPressedChanged:/);
  assert.match(
    qml("ShellAction.qml"),
    /connectedGroup \? motion.pressGroupExpand : motion.pressScaleNormal/,
  );
  assert.match(
    qml("ShellAction.qml"),
    /neighborPressed \? motion.pressGroupCompress/,
  );
});

test("media key-down triggers the same action as pointer input with repeats only for seeking", () => {
  const transport = qml("MediaTransport.qml");
  const content = qml("MediaContent.qml");
  assert.match(
    transport,
    /autoRepeat && action !== "back" && action !== "forward"/,
  );
  assert.match(
    transport,
    /if \(button\)\s*button.trigger\(\);\s*else\s*activate\(action\)/,
  );
  assert.match(transport, /onActivated: root.activate\(modelData.action\)/);
  for (const action of ["play", "previous", "next", "back", "forward"])
    assert.match(
      content,
      new RegExp(
        'fullTransport\\.triggerAction\\("' +
          action +
          '", event\\.isAutoRepeat\\)',
      ),
    );
  assert.match(
    content,
    /if \(!event.isAutoRepeat\)\s*shuffleAction.trigger\(\)/,
  );
  assert.match(
    content,
    /if \(!event.isAutoRepeat\)\s*repeatAction.trigger\(\)/,
  );
});
