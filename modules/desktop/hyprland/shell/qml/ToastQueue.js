// Pure layout policy for bounded notifications. The temporary exit layer
// retains a displaced toast until its morph finishes; it does not consume one
// of the three live slots or force the remaining cards to jump.
function layout(entries, capacity, now, exitDuration) {
  const slots = Math.max(1, Math.floor(capacity));
  let active = 0;
  return entries.map((entry) => {
    if (entry.phase === "closing")
      return {
        phase: "closing",
        slot: Math.min(
          entry.evicted ? slots : slots - 1,
          Math.max(0, entry.slot),
        ),
        removeAt: entry.removeAt,
        evicted: Boolean(entry.evicted),
      };
    if (active < slots)
      return { phase: "visible", slot: active++, removeAt: 0, evicted: false };
    // Overflow uses a vertical conveyor exit, not the ordinary horizontal
    // dismiss. The Wayland popup clips it once it moves below the third slot.
    return {
      phase: "closing",
      slot: slots,
      removeAt: now + exitDuration,
      evicted: true,
    };
  });
}
