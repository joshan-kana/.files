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
