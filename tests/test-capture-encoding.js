const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const root = path.join(__dirname, "../scripts/desktop-shell");
const linux = process.platform === "linux";

function fixture(t) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), "capture-encoding-"));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  const bin = path.join(home, "bin");
  const runtime = path.join(home, "runtime");
  fs.mkdirSync(bin);
  fs.mkdirSync(runtime);
  const env = { ...process.env, HOME: home, XDG_RUNTIME_DIR: runtime,
    XDG_PICTURES_DIR: path.join(home, "Pictures"),
    DESKTOP_SHELL_RECORDING_DIR: path.join(home, "Videos", "Screencasts"),
    PATH: bin + ":" + process.env.PATH };
  function stub(name, body) {
    fs.writeFileSync(path.join(bin, name), "#!/bin/bash\n" + body, { mode: 0o700 });
  }
  function run(name, ...args) {
    return spawnSync("bash", [path.join(root, name + ".sh"), ...args], { env, encoding: "utf8", timeout: 10000 });
  }
  return { home, runtime, env, stub, run };
}

test("recording configuration passes only validated encoding options to wf-recorder", { skip: !linux }, t => {
  const f = fixture(t);
  const config = path.join(f.runtime, "desktop-shell-recording.conf");
  const args = path.join(f.runtime, "args");
  f.stub("wf-recorder", 'printf "%s\\n" "$@" > "$XDG_RUNTIME_DIR/args"\nfor last do :; done\nprintf frame > "$last"\n');
  fs.writeFileSync(config, "Virtual-1\n0,0 640x480\nnone\nmkv\nlibx265\n60\n18\n");
  const result = f.run("record-region");
  assert.equal(result.status, 0, result.stderr);
  const values = fs.readFileSync(args, "utf8").trim().split("\n");
  assert.deepEqual(values.slice(0, 8), ["--output", "Virtual-1", "--codec", "libx265", "--codec-param", "crf=18", "--framerate", "60"]);
  assert.match(values.at(-1), /Recording-.*\.mkv$/);
  assert.equal(fs.statSync(values.at(-1)).mode & 0o777, 0o600);
  fs.writeFileSync(config, "Virtual-1\n0,0 640x480\nnone\nmkv\nnot-a-codec\n60\n18\n");
  assert.equal(f.run("record-region").status, 2);
  assert.equal(f.run("recording-toggle", "start", "Virtual-1", "0,0 640x480", "none", "mkv", "libx264", "999", "18").status, 2);
});

test("saved screenshots support JPEG while clipboard and markup preserve PNG", { skip: !linux }, t => {
  const f = fixture(t);
  const snapshot = path.join(f.runtime, "desktop-shell-capture-fixture.png");
  f.stub("magick", 'if [[ "$1" == identify ]]; then printf "100 100\\n"; else printf "%s\\n" "$@" > "$XDG_RUNTIME_DIR/args"; for last do :; done; printf image > "$last"; fi\n');
  f.stub("systemd-run", "exit 0\n");
  f.stub("wl-copy", "cat >/dev/null\n");
  fs.writeFileSync(snapshot, "source");
  const saved = f.run("frozen-capture", "save", snapshot, "0", "0", "80", "80", "jpg", "85");
  assert.equal(saved.status, 0, saved.stderr);
  assert.match(saved.stdout.trim(), /\.jpg$/);
  assert.match(fs.readFileSync(path.join(f.runtime, "args"), "utf8"), /-quality\n85\n/);
  fs.writeFileSync(snapshot, "source");
  const copied = f.run("frozen-capture", "copy", snapshot, "0", "0", "80", "80", "jpg", "85");
  assert.equal(copied.status, 0, copied.stderr);
  assert.match(copied.stdout.trim(), /\.png$/);
  assert.doesNotMatch(fs.readFileSync(path.join(f.runtime, "args"), "utf8"), /-quality/);
});
