// Read the original notification INI only if it was never imported into
// the shared preference file. The sparse store owns all subsequent writes.
function legacyOverrides(store, previous) {
  const imported = store.legacy("legacyMigrated", false);
  const read = (key, fallback) => {
    const old = imported ? null : previous.value(key, null);
    return old === null || old === undefined
      ? store.legacy(key, fallback)
      : store.coerceLegacy(old, fallback);
  };
  const result = {};
  for (const [key, marker] of [
    ["silent", "preferenceSource"],
    ["presentation", "presentationSource"],
    ["historyEnabled", "historySource"],
  ]) {
    if (read(marker, "") !== "default") result[key] = read(key, false);
  }
  result.quiet = store.objectFromJson(
    store.legacy("quietOverridesJson", "") || "{}",
  );
  result.applications = store.objectFromJson(read("appsJson", "") || "{}");
  return result;
}
