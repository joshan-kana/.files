const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.join(
    __dirname,
    "../modules/desktop/hyprland/shell/qml/LogindInhibitors.js",
  ),
  "utf8",
);
const parse = vm.runInNewContext(source + "\nparseInhibitors");

test("login1 inhibitor readback preserves owner, reason, mode and scope", () => {
  const result = parse(
    JSON.stringify({
      type: "a(ssssuu)",
      data: [[["sleep:shutdown", "Backup", "Saving files", "delay", 1000, 42]]],
    }),
  );
  assert.equal(result.length, 1);
  assert.equal(result[0].who, "Backup");
  assert.equal(result[0].what, "sleep:shutdown");
  assert.equal(result[0].why, "Saving files");
  assert.equal(result[0].mode, "delay");
  assert.equal(result[0].pid, 42);
});

test("empty system locks and malformed readback remain distinct", () => {
  assert.equal(parse('{"type":"a(ssssuu)","data":[[]]}').length, 0);
  for (const value of ["", "{}", '{"type":"a(ssssuu)","data":[[["sleep"]]]}'])
    assert.equal(parse(value), null);
});
