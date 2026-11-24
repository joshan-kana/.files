const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("search focus morphs without modifying input layout or focus ownership", () => {
  const source = qml("SearchFieldSurface.qml");
  assert.match(
    source,
    /cornerRadius: fieldFocused \? theme\.radiusSmall : theme\.radiusMedium/,
  );
  assert.match(
    source,
    /Behavior on cornerRadius \{[\s\S]*?motion: field\.motion/,
  );
  assert.match(
    source,
    /borderWidth: fieldFocused \? theme\.borderFocus : theme\.borderThin/,
  );
  assert.doesNotMatch(source, /Keys\.|forceActiveFocus|\bwidth:|\bheight:/);
});

test("local busy indicator morphs only during visible work and preserves static status in reduced motion", () => {
  const source = qml("PanelStatus.qml");
  assert.match(
    source,
    /animatedBusy: status\.busy && status\.motion\.enabled && status\.visible && status\.hasMessage/,
  );
  assert.match(
    source,
    /visible: !phaseIcon\.animatedBusy\s+text: status\.symbol/,
  );
  assert.match(
    source,
    /SequentialAnimation on radius \{\s*running: phaseIcon\.animatedBusy/,
  );
  assert.match(
    source,
    /NumberAnimation on rotation \{\s*running: phaseIcon\.animatedBusy/,
  );
  assert.match(source, /Accessible\.role: Accessible\.StatusBar/);
});
