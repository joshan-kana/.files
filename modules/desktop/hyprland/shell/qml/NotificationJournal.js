// Durable snapshots are deliberately inert: actions and sender references must
// never survive a Quickshell process or freedesktop notification service exit.
const version = 1;
const limit = 200;
const maxAgeMs = 14 * 24 * 60 * 60 * 1000;
const maxBytes = 2 * 1024 * 1024;

function snapshot(notification, recordId, when, read = false) {
  return {
    recordId,
    protocolId: Number(notification.id ?? notification.protocolId) || 0,
    appName: String(notification.appName || "SYSTEM").slice(0, 256),
    desktopEntry: String(notification.desktopEntry || "").slice(0, 256),
    // Icon names are safe to retain. Never copy sender image paths or bytes.
    appIcon: String(notification.appIcon || "").startsWith("/")
      ? ""
      : String(notification.appIcon || "").slice(0, 256),
    summary: String(notification.summary || "").slice(0, 2048),
    body: String(notification.body || "").slice(0, 16384),
    urgency: Number(notification.urgency) || 0,
    when,
    read: Boolean(read),
    actions: [],
    hasInlineReply: false,
    image: "",
    historical: true,
  };
}

function compact(records, now = Date.now()) {
  let current = Array.from(records || []).filter(
    (record) =>
      record &&
      typeof record.recordId === "string" &&
      Number.isFinite(record.when) &&
      record.when <= now + 60000 &&
      now - record.when <= maxAgeMs,
  );
  current = current.slice(-limit);
  while (
    current.length > 0 &&
    JSON.stringify({ version, records: current }).length > maxBytes
  )
    current.shift();
  return current;
}

function restore(text, now = Date.now()) {
  try {
    const decoded = JSON.parse(text);
    if (decoded.version !== version || !Array.isArray(decoded.records))
      return [];
    return compact(
      decoded.records.map((record) =>
        snapshot(record, record.recordId, record.when, record.read),
      ),
      now,
    );
  } catch (_) {
    return [];
  }
}

function serialize(records, now = Date.now()) {
  return JSON.stringify({ version, records: compact(records, now) });
}
