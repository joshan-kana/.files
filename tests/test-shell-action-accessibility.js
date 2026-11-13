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

test("focusable shared controls use the same pointer, keyboard and visual state owner", () => {
  const state = fs.readFileSync(
    path.join(
      import.meta.dirname,
      "../modules/desktop/hyprland/shell/qml/StateLayer.qml",
    ),
    "utf8",
  );
  const weather = fs.readFileSync(
    path.join(
      import.meta.dirname,
      "../modules/desktop/hyprland/shell/qml/WeatherSummary.qml",
    ),
    "utf8",
  );
  assert.match(
    shellAction,
    /keyboardFocusable: !root\.iconOnly \|\| root\.iconHint/,
  );
  assert.match(state, /activeFocusOnTab: keyboardFocusable && !disabled/);
  assert.match(
    state,
    /event\.key === Qt\.Key_Return \|\| event\.key === Qt\.Key_Enter \|\| event\.key === Qt\.Key_Space/,
  );
  assert.match(state, /visible: root\.keyboardFocusable && root\.activeFocus/);
  assert.match(
    weather,
    /hovered: forecastHit\.pointerHovered \|\| forecastHit\.activeFocus/,
  );
  assert.match(weather, /StateLayer \{\s*id: forecastHit/);
  assert.match(weather, /onActivated: summary\.forecastRequested\(\)/);
});
