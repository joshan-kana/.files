// The login1 ListInhibitors result describes system inhibitor locks, not
// Wayland surface-local idle inhibitors. Keep these sources distinct.
function parseInhibitors(text) {
  let reply;
  try {
    reply = JSON.parse(text);
  } catch (_) {
    return null;
  }
  if (
    reply?.type !== "a(ssssuu)" ||
    !Array.isArray(reply.data) ||
    reply.data.length !== 1 ||
    !Array.isArray(reply.data[0])
  )
    return null;
  const entries = reply.data[0];
  if (
    !entries.every(
      (entry) =>
        Array.isArray(entry) &&
        entry.length === 6 &&
        entry.slice(0, 4).every((value) => typeof value === "string") &&
        entry.slice(4).every((value) => Number.isInteger(value) && value >= 0),
    )
  )
    return null;
  return entries.map(([what, who, why, mode, uid, pid]) => ({
    what,
    who,
    why,
    mode,
    uid,
    pid,
  }));
}
