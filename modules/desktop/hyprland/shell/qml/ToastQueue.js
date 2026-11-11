// Pure layout policy for bounded notifications. Displaced cards remain behind
// the live card in the last occupied slot until their exit completes. The
// viewport never exposes a partially clipped outgoing card.
function layout(entries, capacity, now, exitDuration) {
  const slots = Math.max(1, Math.floor(capacity));
  let active = 0;
  return entries.map((entry) => {
    if (entry.phase === "closing")
      return {
        phase: "closing",
        slot: Math.min(slots - 1, Math.max(0, entry.slot)),
        removeAt: entry.removeAt,
        evicted: Boolean(entry.evicted),
      };
    if (active < slots)
      return { phase: "visible", slot: active++, removeAt: 0, evicted: false };
    // The replacement takes visual ownership of the final slot. Keep the
    // displaced card beneath it rather than sliding a cropped fragment out
    // through the edge of the fixed three-slot viewport.
    return {
      phase: "closing",
      slot: slots - 1,
      removeAt: now + exitDuration,
      evicted: true,
    };
  });
}
