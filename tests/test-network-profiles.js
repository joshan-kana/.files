const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const source = fs.readFileSync(path.join(__dirname, "../modules/desktop/hyprland/shell/qml/NetworkProfiles.js"), "utf8");
const { editableFields, parseProfile, modification } = vm.runInNewContext(source + "\n({editableFields, parseProfile, modification})");
const uuid = "26a510fc-62d9-36f4-b8e6-f3b788a69fc0";
test("saved profile reads escaped IPv6 values without requesting credentials", () => {
    const fields = editableFields("802-3-ethernet");
    const result = parseProfile("connection.autoconnect:yes\nconnection.autoconnect-priority:-999\nconnection.metered:unknown\nipv6.dns:2001\\:db8\\:\\:1\n802-11-wireless-security.psk:secret", fields);
    assert.equal(result["ipv6.dns"], "2001:db8::1");
    assert.equal(result["802-11-wireless-security.psk"], undefined);
});
test("only changed allow-listed properties are passed to nmcli modify; no active link operations", () => {
    const fields = editableFields("802-3-ethernet");
    const original = {"connection.autoconnect": "yes", "connection.autoconnect-priority": "-999", "connection.metered": "unknown"};
    const draft = {...original, "connection.autoconnect-priority": "20", "802-11-wireless-security.psk": "ignore"};
    assert.deepEqual(Array.from(modification(uuid, fields, original, draft)), ["connection","modify","uuid",uuid,"connection.autoconnect-priority","20"]);
    assert.throws(() => modification(uuid, fields, original, {...draft, "connection.autoconnect-priority": "1000"}));
    assert.throws(() => modification("invalid", fields, original, draft));
});
