import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const pathToState = path.join(
  import.meta.dirname,
  "../modules/desktop/hyprland/shell/qml/NotificationState.qml",
);
const source = fs.readFileSync(pathToState, "utf8");

test("notification settings join the canonical categorized desktop preference store", () => {
  assert.match(
    source,
    /property Settings preferences: Settings \{\s*id: settings\s*location:[^\n]*XDG_CONFIG_HOME[^\n]*preferences\.ini[^\n]*\s*category: "Notifications"/,
  );
  assert.match(
    source,
    /property Settings previousPreferences: Settings \{[\s\S]*notifications\.ini/,
  );
  assert.doesNotMatch(
    source,
    /previousSettings\.(setValue|sync|reset|clear)\(/,
  );
});

test("legacy preferences override newly materialized defaults exactly once", () => {
  assert.match(
    source,
    /PreferenceMigration\.migrate\(settings, previousSettings\)/,
  );
  const helper = fs.readFileSync(
    path.join(path.dirname(pathToState), "NotificationPreferenceMigration.js"),
    "utf8",
  );
  assert.match(helper, /if \(current\.legacyMigrated\)\s*return/);
  assert.match(helper, /"appsJson"/);
  assert.match(helper, /previous\.value\(name, null\)/);
  assert.match(helper, /if \(value !== null\)/);
  assert.match(helper, /current\.legacyMigrated = true/);
});

test("restore-declared resets all notification overrides but retains Activity records", () => {
  const body =
    source.match(
      /function resetToDeclared\(\): void \{([\s\S]*?)\n {4}\}/,
    )?.[1] ?? "";
  for (const key of [
    "preferenceSource",
    "presentationSource",
    "historySource",
    "appsJson",
  ])
    assert.ok(
      body.includes(`settings.setValue("${key}"`),
      `missing reset: ${key}`,
    );
  assert.doesNotMatch(body, /clearAll|journal =|archiveFile/);
});

test("migration preserves legacy selections, then newer user changes remain authoritative", () => {
  const helper = fs.readFileSync(
    path.join(path.dirname(pathToState), "NotificationPreferenceMigration.js"),
    "utf8",
  );
  const ctx = vm.createContext({});
  vm.runInContext(helper, ctx);
  const legacy = {
    silent: true,
    appsJson: '{"firefox":{"popups":false}}',
    presentationSource: "user",
  };
  const current = { silent: false, historyEnabled: true };
  const written = [];
  const wrap = (obj, isLegacy = false) => ({
    value(key, fallback) {
      return Object.hasOwn(obj, key) ? obj[key] : fallback;
    },
    setValue(key, value) {
      if (isLegacy) throw Error("legacy store must be read-only");
      obj[key] = value;
      written.push(key);
    },
    sync() {
      if (isLegacy) throw Error("legacy sync is forbidden");
    },
    get legacyMigrated() {
      return obj.legacyMigrated;
    },
    set legacyMigrated(value) {
      if (isLegacy) throw Error("read-only");
      obj.legacyMigrated = value;
    },
    get silent() {
      return obj.silent;
    },
    set silent(value) {
      obj.silent = value;
    },
    get appsJson() {
      return obj.appsJson;
    },
    set appsJson(value) {
      obj.appsJson = value;
    },
    get presentationSource() {
      return obj.presentationSource;
    },
    set presentationSource(value) {
      obj.presentationSource = value;
    },
  });
  const target = wrap(current);
  ctx.migrate(target, wrap(legacy, true));
  assert.equal(
    target.silent,
    true,
    "legacy user override wins over Qt's initialized default",
  );
  assert.equal(target.appsJson, legacy.appsJson);
  assert.equal(target.presentationSource, "user");
  const firstWrites = written.length;
  target.silent = false;
  ctx.migrate(target, wrap(legacy, true));
  assert.equal(target.silent, false, "new preference wins after migration");
  assert.equal(written.length, firstWrites, "repeat migration must be inert");
});
