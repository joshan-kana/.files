const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const shell = path.join(__dirname, "../modules/desktop/hyprland/shell");
const qml = name => fs.readFileSync(path.join(shell, "qml", name + ".qml"), "utf8");

test("Forecast and Status Refresh shortcuts appear on their own button, not in footers", () => {
  const weather = qml("WeatherContent");
  const status = qml("StatusContent");
  const host = qml("ShellExpansionHost");
  const controls = qml("SystemContent");
  for (const [src, owner, name] of [
    [weather,"panel","WeatherContent.refresh"],
    [status,"content","StatusContent.refresh"],
  ]) {
    assert.match(src, /ShellAction \{/);
    assert.match(src, /iconOnly: true/);
    assert.match(src, /inlineIconHint: true/);
    assert.ok(src.includes('shortcut: ' + owner + '.runtime.shellHint("' + name + '")'));
  }
  assert.match(weather, /shellMatchesHint\("WeatherContent\.refresh", event\.key, event\.modifiers\)/);
  assert.doesNotMatch(weather.slice(weather.indexOf("KeyHintStrip {")), /WeatherContent\.refresh/);
  assert.doesNotMatch(host, /ShellExpansionHost\.legend\.refresh_forecast/);
  assert.doesNotMatch(
    controls.slice(controls.indexOf("] : statusOpen ? ["), controls.indexOf("] : recordingsPanel.open ? [")),
    /StatusContent\.refresh/,
  );
});
