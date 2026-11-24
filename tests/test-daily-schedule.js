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
  assert.match(notification, /quietOverridesJson = "\{\}"/);
  assert.match(preferences, /function applyVhsPreset\(name: string\): void/);
  assert.match(
    preferences,
    /for \(const key of vhsParameterKeys\)\s*clearOverride\(key\)/,
  );
  assert.match(preferences, /function resetVhsParameter\(key: string\): void/);
});
