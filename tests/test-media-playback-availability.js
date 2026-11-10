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
    /Row \{\s*width: parent.width\s*height: visible \? 46 : 0\s*visible: card.media.available/,
  );
  assert.match(
    card,
    /title: card.media.shuffled \? "Shuffle on" : "Shuffle off"/,
  );
  assert.match(card, /title: "Repeat " \+ card.media.repeatLabel/);
  assert.doesNotMatch(card, /visible: card.media.playing/);
});

test("Now Playing hides shuffle and repeat without a media player", () => {
  const full = qml("MediaContent.qml");
  assert.match(
    full,
    /title: content.media.shuffled \? "SHUFFLE ON" : "SHUFFLE OFF"\s*visible: content.media.available/,
  );
  assert.match(
    full,
    /title: "REPEAT " \+ content.media.repeatLabel\s*visible: content.media.available/,
  );
  assert.doesNotMatch(full, /visible: content.media.playing/);
});
