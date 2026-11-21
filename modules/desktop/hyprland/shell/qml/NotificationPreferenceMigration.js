// Import values from the old notification-only INI once. The shared desktop
// preference category owns every subsequent write; old state remains untouched
// as rollback material, never as an active competing settings store.
const names = [
  "silent",
  "presentation",
  "historyEnabled",
  "preferenceSource",
  "presentationSource",
  "historySource",
  "appsJson",
];

function migrate(current, previous) {
  if (current.legacyMigrated) return;
  for (const name of names) {
    const value = previous.value(name, null);
    // QtCore.Settings persists declared defaults as the QML object loads.
    // Before the migration marker exists, those newly materialized values
    // are *not* user overrides. The original store is authoritative once.
    if (value !== null) {
      current[name] = value;
      current.setValue(name, value);
    }
  }
  current.legacyMigrated = true;
  current.setValue("legacyMigrated", true);
  current.sync();
}
