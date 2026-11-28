import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const dir = path.join(
  import.meta.dirname,
  "../modules/desktop/hyprland/shell/qml",
);
const source = fs.readFileSync(path.join(dir, "NotificationState.qml"), "utf8");
const ctx = vm.createContext({});
vm.runInContext(
  fs.readFileSync(path.join(dir, "NotificationPreferenceMigration.js"), "utf8"),
  ctx,
);

test("notifications share sparse preference storage and do not write the old INI", () => {
  assert.match(source, /property PreferenceStore preferences: PreferenceStore/);
  assert.match(
    source,
    /settings.initialize\(PreferenceMigration.legacyOverrides\(settings, previousSettings\)\)/,
  );
  assert.doesNotMatch(
    source,
    /previousSettings\.(setValue|sync|reset|clear)\(/,
  );
  const delivery = source
    .split("function resetDeliveryPreferences")[1]
    .split("function scheduleSave")[0];
  assert.match(
    delivery,
    /settings.resetMany\(\["silent", "presentation", "historyEnabled", "quiet"\]\)/,
  );
  assert.match(delivery, /settings.reset\("applications"\)/);
  assert.doesNotMatch(delivery, /clearAll|journal =|archiveFile/);
});

test("notification migration preserves explicit false and application rules, ignores inherited defaults", () => {
  const current = {
    silent: true,
    historyEnabled: false,
    historySource: "default",
    quietOverridesJson: '{"enabled":false}',
  };
  const original = {
    silent: false,
    appsJson: '{"firefox":{"popups":false}}',
    preferenceSource: "user",
  };
  const store = {
    legacy: (key) => current[key],
    coerceLegacy: (value) => value,
    objectFromJson: JSON.parse,
  };
  const previous = { value: (key, fallback) => original[key] ?? fallback };
  const result = ctx.legacyOverrides(store, previous);
  assert.equal(result.silent, false);
  assert.equal(result.historyEnabled, undefined);
  assert.equal(result.quiet.enabled, false);
  assert.equal(result.applications.firefox.popups, false);
  current.legacyMigrated = true;
  assert.equal(ctx.legacyOverrides(store, previous).silent, true);
});

test("quiet overrides obey current field constraints and preserve explicit false", () => {
  const get = (name) =>
    source.match(
      new RegExp(
        "    function " +
          name +
          "\\([^\\n]*\\): \\w+ \\{([\\s\\S]*?)\\n    \\}",
      ),
    )[1];
  const fixture = vm.createContext({
    runtime: {
      constraints: {
        notificationQuietHours: {
          startMinute: { min: 0, max: 1439 },
          endMinute: { min: 0, max: 1439 },
          days: { min: 0, max: 127 },
        },
      },
    },
    quietDefaults: {
      enabled: true,
      startMinute: 1200,
      endMinute: 420,
      days: 127,
    },
    quietOverrides: {
      enabled: false,
      startMinute: 1500,
      endMinute: 360,
      days: "127",
    },
  });
  vm.runInContext(
    "function validQuietPreference(key, value) {" +
      get("validQuietPreference") +
      "} function quietValue(key) {" +
      get("quietValue") +
      "}",
    fixture,
  );
  assert.equal(fixture.quietValue("enabled"), false);
  assert.equal(fixture.quietValue("startMinute"), 1200);
  assert.equal(fixture.quietValue("endMinute"), 360);
  assert.equal(fixture.quietValue("days"), 127);
  fixture.runtime.constraints.notificationQuietHours.endMinute.min = 400;
  assert.equal(fixture.quietValue("endMinute"), 420);
});

test("inheriting notification history policy does not delete archived records", () => {
  assert.doesNotMatch(source, /onHistoryEnabledChanged\s*:/);
  assert.match(source, /journal = Journal\.restore\(archiveFile\.text\(\)\)/);
  const history = source
    .split("function toggleHistory")[1]
    .split("function applicationPreferences")[0];
  assert.match(history, /settings.set\("historyEnabled", !historyEnabled\)/);
  assert.doesNotMatch(history, /clearAll\(\)|applyJournal\(/);
});
