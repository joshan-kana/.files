// Notification actions have protocol identifiers, not positional default semantics.
function explicitActions(actions) {
  return Array.from(actions || []).filter(
    (action) =>
      action &&
      action.identifier !== "default" &&
      action.identifier !== "inline-reply",
  );
}

function defaultAction(actions) {
  return (
    Array.from(actions || []).find(
      (action) => action && action.identifier === "default",
    ) || null
  );
}

// Quickshell exposes the freedesktop timeout in seconds. Zero means no expiry.
function timeoutMs(seconds, urgency, critical, low) {
  if (seconds === 0) return 0;
  if (Number.isFinite(seconds) && seconds > 0)
    return Math.max(250, Math.round(seconds * 1000));
  if (urgency === critical) return 0;
  return urgency === low ? 3500 : 6000;
}

// A desktop entry identifies an application more reliably than display text.
function groupKey(notification) {
  const desktopEntry = (notification && notification.desktopEntry) || "";
  const appName = (notification && notification.appName) || "SYSTEM";
  return desktopEntry
    ? "desktop:" + desktopEntry.toLowerCase()
    : "name:" + appName.toLowerCase();
}

// Keep keyboard selection attached to its notification when another sender
// inserts a newer group at the top of Activity.
function findNotification(groups, notification) {
  if (!notification) return null;
  for (let groupIndex = 0; groupIndex < (groups || []).length; ++groupIndex) {
    const memberIndex = groups[groupIndex].notifications.indexOf(notification);
    if (memberIndex >= 0) return { groupIndex, memberIndex };
  }
  return null;
}
