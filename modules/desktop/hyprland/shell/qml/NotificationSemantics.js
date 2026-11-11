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
