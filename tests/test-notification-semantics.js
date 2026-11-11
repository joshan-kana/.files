const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const qmlRoot = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const script = fs.readFileSync(
  path.join(qmlRoot, "NotificationSemantics.js"),
  "utf8",
);
const ctx = vm.createContext({ Array, Math, Number });
vm.runInContext(script, ctx);
const qml = (name) => fs.readFileSync(path.join(qmlRoot, name), "utf8");

test("the default action is identified by protocol ID, not position", () => {
  const choices = [
    { identifier: "dismiss", text: "Dismiss" },
    { identifier: "default", text: "Open" },
    { identifier: "reply", text: "Reply" },
  ];
  assert.equal(ctx.defaultAction(choices), choices[1]);
  assert.deepEqual(
    Array.from(ctx.explicitActions(choices)).map((action) => action.identifier),
    ["dismiss", "reply"],
  );
  assert.equal(ctx.defaultAction([choices[0]]), null);
  assert.deepEqual(Array.from(ctx.explicitActions(null)), []);
});

test("inline replies are not misrepresented as ordinary action buttons", () => {
  const choices = [
    { identifier: "inline-reply", text: "Reply" },
    { identifier: "archive", text: "Archive" },
  ];
  assert.deepEqual(
    Array.from(ctx.explicitActions(choices)).map((a) => a.identifier),
    ["archive"],
  );
});

test("timeout policy honors never-expire and explicit seconds before urgency defaults", () => {
  assert.equal(ctx.timeoutMs(0, 1, 2, 0), 0);
  assert.equal(ctx.timeoutMs(8.25, 2, 2, 0), 8250);
  assert.equal(ctx.timeoutMs(0.01, 1, 2, 0), 250);
  assert.equal(ctx.timeoutMs(-1, 2, 2, 0), 0);
  assert.equal(ctx.timeoutMs(-1, 0, 2, 0), 3500);
  assert.equal(ctx.timeoutMs(-1, 1, 2, 0), 6000);
});

test("server advertises only rendered notification capabilities", () => {
  const state = qml("NotificationState.qml");
  const card = qml("NotificationCard.qml");
  const popup = qml("NotificationPopup.qml");
  assert.match(state, /imageSupported: true/);
  assert.match(state, /inlineReplySupported: true/);
  assert.match(state, /persistenceSupported: true/);
  assert.match(state, /bodyMarkupSupported: false/);
  assert.match(card, /NotificationArtwork/);
  assert.match(card, /sendReply\(\)/);
  assert.match(popup, /NotificationArtwork/);
  assert.match(popup, /explicitActions/);
  assert.doesNotMatch(
    state,
    /captureKind|notification\.summary === "Screenshot saved"/,
  );
});

test("global notification action uses compositor global shortcut", () => {
  const root = qml("shell.qml");
  const keybind = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/keybindings.nix"),
    "utf8",
  );
  assert.match(root, /name: "notifications-act"/);
  assert.match(root, /notifications\.invokeLatest\(\)/);
  assert.match(keybind, /id = "notifications\.act";/);
});

test("grouping prefers desktop identity over a mutable display name", () => {
  const a = { desktopEntry: "org.example.Client", appName: "Example" };
  const renamed = {
    desktopEntry: "org.example.Client",
    appName: "Example (Work)",
  };
  const other = { desktopEntry: "org.example.Other", appName: "Example" };
  assert.equal(ctx.groupKey(a), ctx.groupKey(renamed));
  assert.notEqual(ctx.groupKey(a), ctx.groupKey(other));
  assert.equal(ctx.groupKey({ appName: "Example" }), "name:example");
});

test("notification direct actions own their canonical on-control keyhints", () => {
  const card = qml("NotificationCard.qml");
  const content = qml("NotificationContent.qml");
  assert.match(
    card,
    /iconHint: true\s+inlineIconHint: true\s+shortcut: card\.selected \? "M" : ""/,
  );
  assert.match(
    card,
    /iconHint: true\s+inlineIconHint: true\s+shortcut: card\.selected \? "R" : ""/,
  );
  assert.match(
    card,
    /iconHint: true\s+inlineIconHint: true\s+shortcut: card\.selected \? "DEL" : ""/,
  );
  assert.match(
    card,
    /shortcut: card\.selected && index < 9 \? String\(index \+ 1\) : ""/,
  );
  assert.match(card, /onActivated: card\.replyFocusRequested\(\)/);
  assert.match(card, /visible: card\.safeActions\.length > 0/);
  assert.match(
    card,
    /model: card\.expanded \? card\.safeActions : card\.safeActions\.slice\(0, 2\)/,
  );
  assert.match(content, /Math\.min\(2, actions\.length\)/);
  assert.match(content, /onReplyFocusRequested:/);
  const footer = content.slice(
    content.indexOf("id: footer"),
    content.indexOf("id: list"),
  );
  assert.doesNotMatch(footer, /shortcut: "(?:M|R|DEL|[1-9])"/);
  assert.match(footer, /shortcut: "J\/K/);
});

test("Escape has one shared owner and describes reply editing accurately", () => {
  const center = qml("NotificationContent.qml");
  const card = qml("NotificationCard.qml");
  const host = qml("ShellExpansionHost.qml");
  const footer = center.slice(
    center.indexOf("id: footer"),
    center.indexOf("id: list"),
  );
  assert.doesNotMatch(footer, /shortcut: "ESC"/);
  assert.match(host, /shortcut: "ESC",\s+label: host\.escapeHintLabel/);
  assert.match(host, /activityContent && activityContent\.replyEditing/);
  assert.match(center, /onReplyFocusChanged: focused =>/);
  assert.match(
    card,
    /onActiveFocusChanged: card\.replyFocusChanged\(activeFocus\)/,
  );
  assert.match(card, /Keys\.onEscapePressed: \{\s+card\.replyFinished\(\);/);
});
