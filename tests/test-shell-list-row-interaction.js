const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const qml = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("list feedback changes the painted squircle without scaling the hit target", () => {
  const row = qml("ShellListRow.qml");
  assert.match(row, /ShellSurface \{/);
  assert.match(
    row,
    /motion\.enabled && pressedFeedback \? theme\.radiusSmall : selected \? theme\.radiusLarge : theme\.radiusMedium/,
  );
  assert.match(row, /borderColor: selected \? selectionColor : "transparent"/);
  assert.match(row, /enabled: root\.motion\.enabled/);
  assert.doesNotMatch(row, /\bscale:|\bwidth:|\bheight:/);
});

test("connectivity rows keep their existing actions and share their animated contour with StateLayer", () => {
  for (const [name, rows] of [
    [
      "NetworkPanel.qml",
      [
        ["networkRow", "networkPress"],
        ["profileRow", "profilePress"],
      ],
    ],
    ["BluetoothPanel.qml", [["deviceRow", "devicePress"]]],
  ]) {
    const source = qml(name);
    for (const [row, press] of rows) {
      assert.match(
        source,
        new RegExp(`delegate: ShellListRow \\{\\s*id: ${row}`),
      );
      assert.match(
        source,
        new RegExp(`pressedFeedback: ${press}\\.visualPressed`),
      );
      assert.match(
        source,
        new RegExp(
          `StateLayer \\{\\s*id: ${press}[\\s\\S]*?cornerRadius: ${row}\\.cornerRadius`,
        ),
      );
    }
  }
  assert.match(qml("NetworkPanel.qml"), /panel\.activateSelected\(\)/);
  assert.match(qml("NetworkPanel.qml"), /panel\.activateSaved\(\)/);
  assert.match(
    qml("BluetoothPanel.qml"),
    /onDoubleClicked: \{[\s\S]*?panel\.activateSelected\(\)/,
  );
});
