// Run against an isolated live Quickshell preview with
// NOTIFICATION_DBUS_LIVE=1 NOTIFICATION_STATE_DIR=/tmp/isolated-state.
// Ordinary repository checks do not replace a user's notification service.
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const live = process.env.NOTIFICATION_DBUS_LIVE === "1";
const service = "org.freedesktop.Notifications";
const object = "/org/freedesktop/Notifications";
const method = "org.freedesktop.Notifications";

function bus(name, signature, ...args) {
  const output = spawnSync(
    "busctl",
    [
      "--user",
      "call",
      service,
      object,
      method,
      name,
      signature,
      ...args.map(String),
    ],
    { encoding: "utf8", timeout: 5000 },
  );
  assert.equal(output.status, 0, `${name}: ${output.stderr}`);
  return output.stdout.trim();
}

function notify({
  app,
  summary,
  body = "",
  icon = "",
  replace = 0,
  actions = [],
  hints = [],
  timeout = 10000,
}) {
  assert.equal(actions.length % 2, 0);
  const output = bus(
    "Notify",
    "susssasa{sv}i",
    app,
    replace,
    icon,
    summary,
    body,
    actions.length,
    ...actions,
    hints.length,
    ...hints.flat(),
    timeout,
  );
  const match = output.match(/^u (\d+)$/);
  assert.ok(match, `invalid Notify response: ${output}`);
  return Number(match[1]);
}

function journal() {
  const root = process.env.NOTIFICATION_STATE_DIR;
  assert.ok(root, "isolated NOTIFICATION_STATE_DIR is mandatory");
  // This fixture deliberately prevents tests from touching the normal profile.
  assert.ok(root.startsWith("/tmp/"), "refusing production history paths");
  const candidates = [];
  const walk = (dir, depth) => {
    if (depth > 5 || !fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isFile() && entry.name === "notifications.json")
        candidates.push(full);
      else if (entry.isDirectory()) walk(full, depth + 1);
    }
  };
  walk(root, 0);
  assert.equal(candidates.length, 1, "exactly one isolated journal expected");
  return JSON.parse(fs.readFileSync(candidates[0], "utf8")).records;
}

async function settle(ms = 500) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitUntil(predicate, timeoutMs = 4000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      if (predicate()) return;
    } catch (error) {
      if (!(error instanceof SyntaxError)) throw error;
    }
    await settle(120);
  }
  assert.fail(
    "timed out waiting for the native coalesced notification journal",
  );
}

test(
  "native notification capabilities match the implemented D-Bus service",
  { skip: !live },
  () => {
    const result = bus("GetCapabilities", "");
    for (const feature of [
      "body",
      "body-markup",
      "body-hyperlinks",
      "actions",
      "action-icons",
      "icon-static",
      "persistence",
      "inline-reply",
    ])
      assert.ok(
        result.includes(`"${feature}"`),
        `missing ${feature}: ${result}`,
      );
    assert.ok(
      !result.includes('"body-images"'),
      "unimplemented embedded body images must not be advertised",
    );
  },
);

test(
  "D-Bus replacement preserves one history record and the same protocol ID",
  { skip: !live },
  async () => {
    const summary = `Replace QA ${process.pid}`;
    const id = notify({
      app: "Integration Sender",
      summary,
      body: "Before",
      icon: "dialog-information",
    });
    assert.equal(
      notify({
        app: "Integration Sender",
        summary,
        body: "After",
        replace: id,
      }),
      id,
    );
    await waitUntil(() =>
      journal().some(
        (entry) => entry.summary === summary && entry.body === "After",
      ),
    );
    const records = journal().filter((entry) => entry.summary === summary);
    assert.equal(records.length, 1);
    assert.equal(records[0].protocolId, id);
    assert.equal(records[0].body, "After");
    bus("CloseNotification", "u", id);
  },
);

test(
  "transient notifications never enter durable history",
  { skip: !live },
  async () => {
    const summary = `Transient QA ${process.pid}`;
    const id = notify({
      app: "Integration Sender",
      summary,
      hints: [["transient", "b", "true"]],
    });
    await settle();
    assert.equal(
      journal().filter((entry) => entry.summary === summary).length,
      0,
    );
    bus("CloseNotification", "u", id);
  },
);

test(
  "native urgency, resident, image-data, action labels and icon parameters are accepted",
  { skip: !live },
  async () => {
    const summary = `Rich QA ${process.pid}`;
    const id = notify({
      app: "Integration Sender",
      summary,
      icon: "dialog-information",
      body: "<b>Markup</b>",
      actions: ["inspect", "Inspect", "archive", "Archive"],
      hints: [
        ["urgency", "y", "2"],
        ["resident", "b", "true"],
        // 1×1 RGBA byte image, stride 4, four bytes per pixel.
        [
          "image-data",
          "(iiibiiay)",
          "1",
          "1",
          "4",
          "true",
          "8",
          "4",
          "4",
          "255",
          "0",
          "0",
          "255",
        ],
      ],
      timeout: 10000,
    });
    await settle();
    const record = journal().find((entry) => entry.summary === summary);
    assert.ok(record, "D-Bus image notification was not accepted");
    assert.equal(record.urgency, 2);
    assert.equal(record.appIcon, "dialog-information");
    assert.deepEqual(record.actions, []);
    bus("CloseNotification", "u", id);
  },
);

test(
  "CloseNotification emits the actual freedesktop closure reason",
  { skip: !live },
  async () => {
    const monitor = spawn(
      "dbus-monitor",
      ["--session", "type='signal',interface='org.freedesktop.Notifications'"],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let output = "";
    monitor.stdout.setEncoding("utf8");
    monitor.stdout.on("data", (data) => {
      output += data;
    });
    try {
      await settle(300);
      const id = notify({
        app: "Integration Sender",
        summary: `Close QA ${process.pid}`,
      });
      bus("CloseNotification", "u", id);
      for (
        let i = 0;
        i < 30 &&
        !new RegExp(
          `member=NotificationClosed\\s+uint32 ${id}\\s+uint32 3`,
        ).test(output);
        ++i
      )
        await settle(100);
      assert.match(
        output,
        new RegExp(`member=NotificationClosed\\s+uint32 ${id}\\s+uint32 3`),
      );
    } finally {
      monitor.kill("SIGTERM");
    }
  },
);

test(
  "finite timeout emits the freedesktop expiry reason without losing durable history",
  { skip: !live },
  async () => {
    const monitor = spawn(
      "dbus-monitor",
      ["--session", "type='signal',interface='org.freedesktop.Notifications'"],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let output = "";
    monitor.stdout.setEncoding("utf8");
    monitor.stdout.on("data", (data) => {
      output += data;
    });
    try {
      await settle(300);
      const summary = `Expire QA ${process.pid}`;
      const id = notify({ app: "Integration Sender", summary, timeout: 350 });
      const reason = new RegExp(
        `member=NotificationClosed\\s+uint32 ${id}\\s+uint32 1`,
      );
      await waitUntil(() => reason.test(output), 5500);
      await waitUntil(() =>
        journal().some((entry) => entry.summary === summary),
      );
      const record = journal().find((entry) => entry.summary === summary);
      assert.ok(record);
      assert.deepEqual(record.actions, []);
    } finally {
      monitor.kill("SIGTERM");
    }
  },
);
