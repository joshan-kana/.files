const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const f = vm.runInNewContext(
  fs.readFileSync(
    path.join(
      __dirname,
      "../modules/desktop/hyprland/shell/qml/ResourceDisks.js",
    ),
    "utf8",
  ) + "\n({filesystems,counters,rates})",
);
test("mounted filesystem choices deduplicate bind mounts and exclude nonblock mounts", () => {
  const result = f.filesystems(
    JSON.stringify({
      filesystems: [
        {
          target: "/nix/store",
          source: "/dev/sda3[/nix/store]",
          "maj:min": "8:3",
        },
        { target: "/", source: "/dev/sda3", "maj:min": "8:3" },
        { target: "/home", source: "/dev/sda2", "maj:min": "0:52" },
        { target: "/mnt/share", source: "remote", "maj:min": "0:67" },
      ],
    }),
  );
  assert.equal(
    JSON.stringify(result.map((r) => r.target)),
    JSON.stringify(["/", "/home"]),
  );
  assert.equal(f.filesystems("bad").length, 0);
});
test("diskstats counters use kernel 512-byte sectors and never invent pooled filesystem I/O", () => {
  const raw = "8 3 sda3 1 0 100 0 2 0 200 0 0 0 0";
  const c = f.counters(raw, { device: "8:3" });
  assert.equal(c.read, 51200);
  assert.equal(c.write, 102400);
  assert.equal(f.counters(raw, { device: "0:52" }), null);
  assert.equal(
    f.counters(raw, { device: "0:52", source: "/dev/sda3" }).read,
    51200,
  );
  assert.equal(
    f.counters(raw, { device: "0:52", source: "/dev/mapper/pool" }),
    null,
  );
  const r = f.rates(c, { read: 52224, write: 104448 }, 2);
  assert.equal(r.read, 512);
  assert.equal(r.write, 1024);
  assert.equal(f.rates(c, { read: 0, write: 0 }, 1), null);
  assert.equal(f.rates(null, c, 1), null);
});
