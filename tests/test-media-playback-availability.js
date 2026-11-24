const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("compact media actions disappear with no player without hiding paused media controls", () => {
  const card = qml("ControlsMediaCard.qml");
  assert.match(
    card,
    /Row \{\s*id: transportRow\s*width: implicitWidth\s*height: visible \? implicitHeight : 0\s*visible: card.media.available\s*anchors.horizontalCenter: parent.horizontalCenter/,
  );
  assert.match(
    card,
    /title: card.media.shuffled \? "Shuffle on" : "Shuffle off"/,
  );
  assert.match(card, /title: "Repeat " \+ card.media.repeatLabel/);
  assert.doesNotMatch(card, /visible: card.media.playing/);
});

test("Now Playing keeps shuffle and repeat visible but disabled without a player", () => {
  const full = qml("MediaContent.qml");
  for (const [title, availability] of [
    [
      'title: content.media.shuffled ? "Shuffle on" : "Shuffle off"',
      "shuffleAvailable",
    ],
    ['title: "Repeat " + content.media.repeatLabel', "repeatAvailable"],
  ]) {
    const start = full.indexOf(title);
    assert.notEqual(start, -1, `missing action ${title}`);
    const end = full.indexOf("onActivated:", start);
    assert.notEqual(end, -1, `missing activation for ${title}`);
    const action = full.slice(start, end);
    assert.doesNotMatch(action, /visible:\s*content.media.available/);
    assert.match(
      action,
      new RegExp(`enabled: content\\.media\\.${availability}`),
    );
  }
});

test("compact shuffle and repeat buttons match the shared transport height", () => {
  const card = qml("ControlsMediaCard.qml");
  const transport = qml("MediaTransport.qml");
  const match = transport.match(
    /delegate: ShellAction \{[\s\S]*?height:\s*Math.max\(!root.compact && !root.minimal && modelData.action === "play" \? 58 : (\d+), implicitHeight\)/,
  );
  assert.ok(match, "media transport buttons should declare a height");
  const transportHeight = Number(match[1]);
  for (const id of ["shuffleButton", "repeatButton"]) {
    const start = card.indexOf(`id: ${id}`);
    assert.notEqual(start, -1, `missing ${id}`);
    const action = card.slice(start);
    const height = action.match(
      /\bheight:\s*Math.max\((\d+), implicitHeight\)/,
    );
    assert.ok(height, `missing height for ${id}`);
    assert.equal(
      Number(height[1]),
      transportHeight,
      `${id} must align with media transport`,
    );
  }
});
