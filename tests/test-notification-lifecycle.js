import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const root = path.join(
  import.meta.dirname,
  "../modules/desktop/hyprland/shell/qml",
);
function helper(name) {
  const source = fs.readFileSync(path.join(root, name), "utf8");
  const context = vm.createContext({});
  vm.runInContext(source, context);
  return context;
}
const policy = helper("NotificationPolicy.js");
const journal = helper("NotificationJournal.js");

test("locked and presentation sessions never expose alerts, including critical", () => {
  for (const urgent of [false, true]) {
    assert.equal(policy.mayShowToast(true, false, false, false, urgent), false);
    assert.equal(policy.mayShowToast(false, true, false, false, urgent), false);
  }
  assert.equal(policy.mayShowToast(false, false, true, false, true), true);
  assert.equal(policy.mayShowToast(false, false, true, false, false), false);
  assert.equal(policy.mayShowToast(false, false, false, true, true), true);
  assert.equal(policy.mayShowToast(false, false, false, true, false), false);
});

test("markup permits safe styling and explicit ordinary hyperlinks only", () => {
  assert.equal(
    policy.permittedUrl("https://example.org/a"),
    "https://example.org/a",
  );
  for (const unsafe of [
    "javascript:alert(1)",
    "file:///etc/passwd",
    "data:text/html,a",
    "https://a\nhttps://b",
  ])
    assert.equal(policy.permittedUrl(unsafe), "");
  const content = policy.safeBody(
    '<b>Hi</b><img src="file:///etc/passwd"><a href="javascript:alert(1)">unsafe</a><a href="https://example.org">safe</a>',
  );
  assert.ok(content.includes("<b>Hi</b>"));
  assert.ok(!content.includes("<img"));
  assert.ok(!content.includes("javascript:"));
  assert.ok(content.includes('<a href="https://example.org">safe</a>'));
});

test("history restores snapshots but no stale sender callbacks or image paths", () => {
  const when = Date.now();
  const image = "/tmp/sensitive.png";
  const record = journal.snapshot(
    {
      id: 7,
      appName: "App",
      appIcon: image,
      summary: "hello",
      body: "private",
      urgency: 2,
      actions: [{ identifier: "open" }],
      image,
    },
    "stable",
    when,
    true,
  );
  assert.equal(record.actions.length, 0);
  assert.equal(record.appIcon, "");
  assert.equal(record.image, "");
  assert.equal(record.hasInlineReply, false);
  const output = journal.restore(journal.serialize([record], when), when);
  assert.equal(output.length, 1);
  assert.equal(output[0].read, true);
  assert.equal(output[0].body, "private");
});

test("durable history is bounded by age, count and bytes", () => {
  const now = Date.now();
  const records = Array.from({ length: 400 }, (_, n) =>
    journal.snapshot(
      { appName: "App", body: "x".repeat(15000) },
      String(n),
      now - n * 2000,
    ),
  );
  const restored = journal.restore(journal.serialize(records, now), now);
  assert.ok(restored.length <= 200);
  assert.ok(journal.serialize(restored, now).length <= 2 * 1024 * 1024);
  assert.equal(
    journal.compact([{ recordId: "old", when: now - 15 * 86400000 }], now)
      .length,
    0,
  );
});

test("closing a toast preserves notification before invalidating the model row", () => {
  const popup = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  assert.match(
    popup,
    /const notification = item\.notification;\s*const expire = notification/,
  );
  assert.match(
    popup,
    /root\.popups\.remove\(i\);\s*if \(expire && root\.isLive\(notification\)\)\s*notification\.expire\(\);/,
  );
});

test("history shortcut is handled before ordinary H navigation", () => {
  const content = fs.readFileSync(
    path.join(root, "NotificationContent.qml"),
    "utf8",
  );
  const history = content.indexOf(
    "event.key === Qt.Key_H && (event.modifiers & Qt.ShiftModifier)",
  );
  const nav = content.indexOf(
    "event.key === Qt.Key_Left || event.key === Qt.Key_H",
  );
  assert.ok(history > 0 && nav > history);
});

test("muting one application does not silence the whole desktop", () => {
  const state = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  assert.match(state, /hideApplicationPopups\(key\)/);
  assert.match(
    state,
    /NotificationSemantics\.groupKey\(notification\) === groupKey/,
  );
  assert.match(state, /if \(show\)\s*showPopup\(notification\);/);
});

test("locking hides the entire notification status island", () => {
  const bar = fs.readFileSync(path.join(root, "AmbientBar.qml"), "utf8");
  assert.match(
    bar,
    /visible: !bar\.notificationState\.locked && barContent\.width/,
  );
});

test("ordinary popup suppression never accesses a removed ListModel wrapper", () => {
  const state = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  assert.match(
    state,
    /function concealOrdinaryPopups\(\): void \{[\s\S]*?const notification = item\.notification;[\s\S]*?popups\.remove\(i\);\s*if \(notification\.transient && isLive\(notification\)\)/,
  );
  assert.match(state, /if \(liveById\[key\] === notification\)/);
});

test("graceful desktop shutdown commits pending bounded history atomically", () => {
  const state = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  assert.match(
    state,
    /Component\.onDestruction:[\s\S]*?archiveFile\.blockWrites = true;\s*archiveFile\.setText\(Journal\.serialize\(journal\)\)/,
  );
  const journalFile = fs.readFileSync(
    path.join(root, "NotificationJournal.js"),
    "utf8",
  );
  assert.match(journalFile, /const maxBytes = 2 \* 1024 \* 1024/);
});

test("only safe theme icon names, never arbitrary sender paths, survive restart", () => {
  const now = Date.now();
  for (const icon of [
    "/etc/passwd",
    "file:///home/user/a.png",
    "https://example.net/image",
    "../../secret",
    "a/b",
  ])
    assert.equal(journal.snapshot({ appIcon: icon }, "id", now).appIcon, "");
  assert.equal(
    journal.snapshot({ appIcon: "dialog-information" }, "id", now).appIcon,
    "dialog-information",
  );
});

test("Qt Quick Text link activation uses its supported onLinkActivated signal", () => {
  for (const file of ["NotificationPopup.qml", "NotificationCard.qml"]) {
    const source = fs.readFileSync(path.join(root, file), "utf8");
    assert.match(source, /textFormat: Text.StyledText\s+onLinkActivated:/);
    assert.doesNotMatch(source, /textInteractionFlags:/);
  }
});

test("clearing stored notifications never closes an already released Qt handle twice", () => {
  const source = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  const clear =
    source.match(/function clearAll\(\): void \{([\s\S]*?)\n {4}\}/)?.[1] ?? "";
  assert.match(clear, /hidePopup\(\);[\s\S]*?applyJournal\(\[\]\)/);
  assert.doesNotMatch(
    clear,
    /notification\.dismiss\(\)|notification\.expire\(\)|tracked\s*=/,
  );
  assert.match(
    source,
    /function isLive\(notification\): bool \{[\s\S]*?server\.trackedNotifications\.values\.includes\(notification\)/,
  );
  assert.match(
    source,
    /if \(isLive\(live\) && live\.tracked\)\s*live\.tracked = false/,
  );
});

test("dismissal handles persistent and transient records without double close", () => {
  const source = fs.readFileSync(
    path.join(root, "NotificationState.qml"),
    "utf8",
  );
  const dismiss =
    source.match(
      /function dismiss\(notification\): void \{([\s\S]*?)\n {4}\}/,
    )?.[1] ?? "";
  assert.match(dismiss, /const stored = !!key && journal\.some/);
  assert.match(dismiss, /if \(stored\)[\s\S]*?applyJournal\(journal\.filter/);
  assert.match(
    dismiss,
    /else if \(isLive\(notification\)\)\s*[\s\S]*?notification\.dismiss\(\)/,
  );
  assert.match(
    source,
    /function invokeAction\(notification, index: int\): void \{[\s\S]*?if \(!isLive\(notification\)/,
  );
  assert.match(
    source,
    /function sendReply\(notification, message: string\): void \{[\s\S]*?if \(!isLive\(notification\)/,
  );
});
