const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

test("Quickshell restarts on the generated theme as well as runtime source", () => {
  const moduleText = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  assert.match(
    moduleText,
    /X-Restart-Triggers = \[\s+runtimeConfig\s+config\.xdg\.configFile\."linux-desktop\/theme\.json"\.source\s+\];/,
  );
  assert.doesNotMatch(moduleText, /systemd\.user\.paths\.linux-desktop-theme/);
});
