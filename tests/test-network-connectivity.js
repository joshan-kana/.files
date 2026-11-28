const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.join(__dirname, "../modules/desktop/hyprland/shell/qml");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const f = vm.runInNewContext(
  read("NetworkProfiles.js") + "\n({ connectivityPolicy, connectivityResult })",
);
const policy = (available, enabled) =>
  [available, enabled]
    .map((data) => JSON.stringify({ type: "b", data }))
    .join("\n");
test("connectivity follows the native configured-probe policy", () => {
  assert.equal(f.connectivityPolicy(policy(false, false)).available, false);
  assert.equal(f.connectivityPolicy(policy(true, false)).enabled, false);
  assert.equal(f.connectivityPolicy(policy(true, true)).enabled, true);
  assert.equal(f.connectivityPolicy("invalid"), null);
});
test("native connectivity classifications are distinct from failure", () => {
  for (const [state, label] of [
    [0, "Unknown connectivity"],
    [1, "No network connectivity"],
    [2, "Captive portal detected"],
    [3, "Limited connectivity"],
    [4, "Full connectivity"],
  ])
    assert.equal(
      f.connectivityResult(JSON.stringify({ type: "u", data: [state] })),
      label,
    );
  assert.equal(f.connectivityResult('{"type":"u","data":[99]}'), null);
  assert.equal(f.connectivityResult(""), null);
});
test("the native probe does not run when unavailable or disabled", () => {
  const qml = read("NetworkPanel.qml");
  assert.match(
    qml,
    /if \(policy === null \|\| !policy.available \|\| !policy.enabled\)/,
  );
  assert.match(qml, /"org.freedesktop.NetworkManager", "CheckConnectivity"/);
  assert.match(
    read("SystemContent.qml"),
    /networkPanel.invoke\("triggerConnectivityCheck"\)/,
  );
});
