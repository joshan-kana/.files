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
    if (value !== null && current.value(name, null) === null) {
      current[name] = value;
      current.setValue(name, value);
    }
  }
  current.legacyMigrated = true;
  current.setValue("legacyMigrated", true);
  current.sync();
}
