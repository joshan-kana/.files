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
