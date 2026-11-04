const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");
const surface = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/SquircleSurface.qml",
  ),
  "utf8",
);

test("startup path bindings retain valid fallback while geometry QtObject initializes", () => {
  assert.match(
    surface,
    /readonly property string emptyPathData: "M 0 0 L 0\.01 0 L 0 0\.01 Z"/,
  );
  assert.match(surface, /typeof geometry\.cornerPoint !== "function"/);
  assert.match(surface, /return "";/);
  assert.match(surface, /const first = geometry\.cornerPoint/);
});
