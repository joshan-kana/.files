// Shared filtering for contextual actions, regardless of the presenting panel.
function filtered(actions, query) {
  const needle = String(query || "")
    .trim()
    .toLowerCase();
  const source = Array.isArray(actions) ? actions : [];
  if (!needle) return source;
  const words = needle.split(/\s+/).filter(Boolean);
  return source
    .map((entry, index) => {
      const title = String(entry.name || "").toLowerCase();
      const subtitle = String(entry.genericName || "").toLowerCase();
      const haystack = title + " " + subtitle;
      if (!words.every((word) => haystack.includes(word))) return null;
      const rank = title === needle ? 0 : title.startsWith(needle) ? 1 : 2;
      return { entry, index, rank };
    })
    .filter(Boolean)
    .sort((a, b) => a.rank - b.rank || a.index - b.index)
    .map((result) => result.entry);
}

function clipboardActions(entry, canOpenLink) {
  if (!entry) return [];
  const action = (id, name, icon, genericName) => ({
    kind: "paletteAction",
    action: id,
    name,
    icon,
    genericName: genericName || "",
    key: "",
  });
  const actions = [action("copy", "Copy to Clipboard", "edit-copy")];
  if (canOpenLink)
    actions.push(action("openLink", "Open Link", "internet-web-browser"));
  if (entry.pinned) {
    actions.push(
      action("unpin", "Unpin Entry", "bookmark-remove", "Remove saved copy"),
    );
  } else {
    if (entry.kind !== "BINARY")
      actions.push(
        action("pin", "Pin Entry", "bookmark-new", "Keep a private local copy"),
      );
    actions.push(
      action("delete", "Delete Entry", "edit-delete", "Remove this entry only"),
    );
  }
  return actions;
}

function historyFilter(items, query, kind) {
  const words = String(query || "")
    .trim()
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
  return (Array.isArray(items) ? items : [])
    .filter(
      (item) =>
        kind === "all" ||
        (kind === "pinned" ? item.pinned : item.kind === kind),
    )
    .filter((item) =>
      words.every((word) =>
        (item.preview + " " + item.kind).toLowerCase().includes(word),
      ),
    )
    .slice(0, 100);
}

function safeWebUrl(text) {
  const value = String(text || "").trim();
  return value.length <= 2048 &&
    /^https?:\/\/(?:[a-z0-9.-]+|\[[a-f0-9:]+\])(?::[0-9]{1,5})?(?:[/?#][^\s]*)?$/i.test(
      value,
    ) &&
    !/[\x00-\x1f\x7f]/.test(value)
    ? value
    : "";
}
