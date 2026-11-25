const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const qml = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const schedule = vm.runInNewContext(
  fs.readFileSync(path.join(qml, "DailySchedule.js"), "utf8") +
    "\n({activeAt, nextTransition})",
);
const date = (day, hour, minute = 0) => new Date(2026, 10, day, hour, minute);

test("overnight intervals belong to the selected start day", () => {
  const friday = 1 << 5;
  assert.equal(schedule.activeAt(date(20, 21, 59), 1320, 420, friday), false);
  assert.equal(schedule.activeAt(date(20, 22), 1320, 420, friday), true);
  assert.equal(schedule.activeAt(date(21, 6, 59), 1320, 420, friday), true);
  assert.equal(schedule.activeAt(date(21, 7), 1320, 420, friday), false);
  assert.equal(schedule.activeAt(date(21, 22), 1320, 420, friday), false);
  assert.equal(
    schedule.nextTransition(date(21, 1), 1320, 420, friday),
    +date(21, 7),
  );
});
test("same-day intervals, disabled day masks and equal endpoints have explicit semantics", () => {
  assert.equal(schedule.activeAt(date(23, 9), 540, 1020, 62), true);
  assert.equal(schedule.activeAt(date(23, 17), 540, 1020, 62), false);
  assert.equal(schedule.activeAt(date(23, 9), 540, 540, 127), false);
  assert.equal(schedule.activeAt(date(23, 9), 540, 1020, 0), false);
  assert.equal(schedule.nextTransition(date(23, 9), 540, 540, 127), 0);
  assert.equal(
    schedule.nextTransition(date(23, 18), 540, 1020, 62),
    +date(24, 9),
  );
});
test("notification suppression and VHS presets retain one authoritative owner", () => {
  const notification = fs.readFileSync(
    path.join(qml, "NotificationState.qml"),
    "utf8",
  );
  const preferences = fs.readFileSync(
    path.join(qml, "AppearancePreferences.qml"),
    "utf8",
  );
  assert.match(
    notification,
    /manualSilent \|\| temporarilySilent \|\| \(quietActive && quietPauseUntil <= clockMs\)/,
  );
  assert.match(
    notification,
    /temporarySilentUntil = clockMs \+ minutes \* 60000/,
  );
  assert.match(notification, /Schedule.nextTransition/);
  assert.match(notification, /settings\.reset\("quiet"\)/);
  assert.match(preferences, /function applyVhsPreset\(name: string\): void/);
  assert.match(
    preferences,
    /for \(const key of vhsParameterKeys\)\s*clearOverride\(key\)/,
  );
  assert.match(preferences, /saved\.setMany\(reactivePresets\[name\]\)/);
  assert.match(preferences, /saved\.setMany\(vhsPresets\[name\]\)/);
  assert.doesNotMatch(preferences, /Object\.fromEntries/);
  assert.match(preferences, /function resetVhsParameter\(key: string\): void/);
});

test("named presets remain independent of parameter ordering and invalid choices", () => {
  const preferences = fs.readFileSync(
    path.join(qml, "AppearancePreferences.qml"),
    "utf8",
  );
  const namesBody = preferences
    .split("function presetNames(presets: var, keys: var): var {")[1]
    .split("\n    }")[0];
  const selectedBody = preferences
    .split("function selectedPreset(presets: var, keys: var): string {")[1]
    .split("\n    }")[0];
  const names = new Function("presets", "keys", "saved", namesBody);
  const selected = new Function(
    "presets",
    "keys",
    "hasOverride",
    "presetNames",
    "effective",
    selectedBody,
  );
  const presets = {
    Subtle: { speed: 0.8, strength: 0.25 },
    Default: null,
    Strong: { strength: 0.9, speed: 1.5 },
  };
  let maxStrength = 1;
  const saved = {
    valid: (key, value) =>
      typeof value === "number" && (key !== "strength" || value <= maxStrength),
  };
  const available = (values, keys) => names(values, keys, saved);
  const values = { speed: 0.8, strength: 0.25 };
  assert.deepEqual(available(presets, ["strength", "speed"]), [
    "Subtle",
    "Default",
    "Strong",
  ]);
  assert.equal(
    selected(
      presets,
      ["strength", "speed"],
      () => true,
      available,
      (key) => values[key],
    ),
    "Subtle",
  );
  assert.equal(
    selected(
      presets,
      ["speed", "strength"],
      () => true,
      available,
      (key) => values[key],
    ),
    "Subtle",
  );
  assert.equal(
    selected(
      presets,
      ["speed", "strength"],
      () => false,
      available,
      (key) => values[key],
    ),
    "Default",
  );
  maxStrength = 0.5;
  assert.deepEqual(available(presets, ["speed", "strength"]), [
    "Subtle",
    "Default",
  ]);
  assert.deepEqual(available(presets, ["speed", "strength", "newParameter"]), [
    "Default",
  ]);
});
