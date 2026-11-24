const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const qml = (name) => fs.readFileSync(path.join(root, name), "utf8");
test("wall clock formats midnight, noon and overnight schedule boundaries consistently", () => {
  const format = vm.runInNewContext(
    qml("ClockFormatting.js") + "\n({minutesLabel, wallClock})",
  );
  for (const [minute, label] of [
    [0, "12:00 AM"],
    [7 * 60, "7:00 AM"],
    [720, "12:00 PM"],
    [22 * 60, "10:00 PM"],
    [1439, "11:59 PM"],
  ]) {
    assert.equal(format.minutesLabel(minute), label);
    assert.equal(
      format.wallClock(
        new Date(2026, 0, 1, Math.floor(minute / 60), minute % 60),
      ),
      label,
    );
  }
  for (const name of [
    "SettingsDetail.qml",
    "WallpaperPanel.qml",
    "NightLightState.qml",
    "WeatherState.qml",
    "AmbientBar.qml",
    "LockScreen.qml",
    "SystemContent.qml",
  ])
    assert.match(qml(name), /ClockFormatting\./);
});
test("collapsed groups have real stack geometry and a single selected expansion action", () => {
  assert.match(
    qml("NotificationContent.qml"),
    /stacked: !groupItem.expanded && groupItem.modelData.notifications.length > 1/,
  );
  assert.match(
    qml("NotificationContent.qml"),
    /model: member.stacked \? 2 : 0/,
  );
  assert.match(
    qml("NotificationCard.qml"),
    /shortcut: card.selected \? card.runtime.shellHint\("NotificationContent.expand"\) : ""/,
  );
  assert.match(qml("NotificationCard.qml"), /switchControl: true/);
});
test("signal meter is based on measured peaks rather than gain", () => {
  const meter = qml("AudioPeakMeter.qml");
  assert.match(meter, /PwNodePeakMonitor/);
  assert.match(meter, /monitor.peaks\[index\]/);
  assert.match(meter, /channelRow.displayedAmplitude > index \/ count/);
  assert.doesNotMatch(meter, /audio.volume/);
});
test("forecast range and schedule use data rather than normalized synthetic samples", () => {
  assert.match(qml("WeatherDay.qml"), /dayCard.day.high - dayCard.day.low/);
  assert.match(qml("WeatherContent.qml"), /lowBound: Math.min/);
  assert.match(qml("ScheduleBand.qml"), /band.startMinute > band.endMinute/);
  assert.match(
    qml("SettingsDetail.qml"),
    /temperatureTrack: modelData.key === "temperature"/,
  );
});
