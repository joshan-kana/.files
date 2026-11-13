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

// The notification server and queue remain singular. A compositor output
// owns only its visible three-card layout; moving keyboard focus must never
// transport already displayed alerts to another monitor.
function layoutByOutput(
  entries,
  capacities,
  defaultCapacity,
  now,
  exitDuration,
) {
  const groups = new Map();
  entries.forEach((entry, index) => {
    const output = String(entry.outputName || "");
    if (!groups.has(output)) groups.set(output, []);
    groups.get(output).push({ entry, index });
  });
  const result = Array(entries.length);
  for (const [output, group] of groups) {
    const capacity =
      capacities && capacities[output] ? capacities[output] : defaultCapacity;
    const arranged = layout(
      group.map(({ entry }) => entry),
      capacity,
      now,
      exitDuration,
    );
    group.forEach(({ index }, i) => {
      result[index] = arranged[i];
    });
  }
  return result;
}
