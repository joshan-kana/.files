import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const shellAction = fs.readFileSync(
  path.join(
    import.meta.dirname,
    "../modules/desktop/hyprland/shell/qml/ShellAction.qml",
  ),
  "utf8",
);

test("shared shell controls expose actionable screen-reader buttons", () => {
  assert.match(shellAction, /Accessible\.role: Accessible\.Button/);
  assert.match(shellAction, /Accessible\.name: title/);
  assert.match(
    shellAction,
    /Accessible\.onPressAction: \{\s*if \(root\.enabled\)\s*root\.activated\(\)/,
  );
  assert.match(shellAction, /onActivated: root\.activated\(\)/);
});
