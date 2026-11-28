const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const qml = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const source = (name) => fs.readFileSync(path.join(qml, name), "utf8");
test("weather formatting and coordinate validation do not alter provider measurements", () => {
  const f = vm.runInNewContext(
    source("WeatherFormatting.js") + "\n({temperature, wind, coordinates})",
  );
  assert.equal(f.temperature(0, "imperial"), "32°");
  assert.equal(f.temperature(25, "metric"), "25°");
  assert.equal(f.wind(16.09344, "imperial"), "10 mph");
  assert.equal(f.wind(16.09344, "metric"), "16 km/h");
  assert.deepEqual(
    Array.from(f.coordinates("-31.95, 115.86")),
    [-31.95, 115.86],
  );
  assert.equal(f.coordinates(", "), null);
  assert.equal(f.coordinates("91, 115"), null);
  assert.match(
    source("WeatherState.qml"),
    /preferredLocation: saved\.value\("location"\)/,
  );
  assert.match(source("WeatherState.qml"), /weather.finishObsoleteRequest\(\)/);
});
test("media selection distinguishes the current session from persistent app identity", () => {
  const f = vm.runInNewContext(
    source("MediaSelection.js") + "\n({stablePlayerId, choosePlayer})",
  );
  const first = {
    desktopEntry: "player-a",
    dbusName: "a.instance1",
    trackTitle: "A",
  };
  const second = {
    desktopEntry: "player-b",
    dbusName: "b.instance2",
    isPlaying: true,
  };
  const restored = { ...first, dbusName: "a.instance3" };
  assert.equal(f.choosePlayer([first, second], "", "player-a"), first);
  assert.equal(
    f.choosePlayer([first, second], "b.instance2", "player-a"),
    second,
  );
  assert.equal(f.choosePlayer([restored, second], "", "player-a"), restored);
  assert.equal(f.choosePlayer([second], "", "player-a"), second);
  assert.equal(f.choosePlayer([], "", "player-a"), null);
});
