const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const shell = fs.readFileSync(path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"), "utf8");
const qml = (name) => fs.readFileSync(path.join(__dirname, `../modules/desktop/hyprland/shell/qml/${name}`), "utf8");

test("all-display wallpaper supersedes older output selections and players", () => {
  const library = shell.slice(shell.indexOf("wallpaperLibrary = pkgs.writeShellApplication"), shell.indexOf("wallpaperVideoFromState = pkgs.writeShellApplication"));
  const set = library.slice(library.indexOf("            set)"), library.indexOf("            reset)"));
  assert.match(set, /if \[ "\$output" = all \]; then\s+# Applying to all displays[\s\S]*systemctl --user stop "linux-desktop-wallpaper-video@\$monitor\.service"/);
  assert.match(set, /if \[ "\$output" = all \]; then\s+# Do not retain stale output overrides[\s\S]*rm -f "\$selection"/);
  assert.match(set, /elif \[ -f "\$state_dir\/all\.wall" \]; then/);
  assert.match(set, /systemctl --user restart "\$unit"/);
});

test("all dimming roles use a dark palette token regardless of colour scheme", () => {
  const theme = qml("Theme.qml");
  assert.match(theme, /readonly property color scrimBase: dark \? background : textStrong/);
  for (const role of ["scrim", "contextualScrim", "scrimStrong", "scrimHeavy"])
    assert.match(theme, new RegExp(`readonly property color ${role}: Qt\\.rgba\\(scrimBase\\.r, scrimBase\\.g, scrimBase\\.b,`));
  assert.match(qml("ScreenshotPicker.qml"), /readonly property color scrim: picker\.theme\.scrimBase/);
  assert.match(qml("PolkitDialog.qml"), /color: auth\.theme\.scrimStrong/);
});

test("notification viewport remains stable as the number of toasts changes", () => {
  const source = qml("NotificationPopup.qml");
  const slots = source.match(/readonly property int maxToastSlots: ([^\n]+)/)?.[1];
  assert.ok(slots);
  assert.doesNotMatch(slots, /toastCount|popups\.count/);
  assert.match(source, /implicitHeight: Math\.max\(1, maxToastSlots \* cardHeight/);
  assert.match(source, /visible: slot < popup\.maxToastSlots \|\| evicted/);
  assert.doesNotMatch(source, /implicitHeight:[^\n]*(toastCount|visibleToastCount)/);
  assert.match(source, /y: slot \* \(popup\.cardHeight \+ popup\.cardGap\)/);
});

test("selecting an all-display video clears stale output ownership before playback", () => {
  const { spawnSync } = require("node:child_process");
  const os = require("node:os");
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "wallpaper-all-set-"));
  try {
    const library = shell.slice(shell.indexOf("wallpaperLibrary = pkgs.writeShellApplication"), shell.indexOf("wallpaperVideoFromState = pkgs.writeShellApplication"));
    const script = library.slice(library.indexOf("text = ''") + "text = ''".length, library.lastIndexOf("'';"))
      .replaceAll("''${", "${")
      .replaceAll("${wallpaperTransition}", "transition_args=(--transition-type none)")
      .replaceAll("${wallpaperTransitionDuration}", "0");
    const scriptFile = path.join(scratch, "library.sh");
    const bin = path.join(scratch, "bin");
    const state = path.join(scratch, "state", "linux-desktop", "wallpapers");
    fs.mkdirSync(bin, { recursive: true });
    fs.mkdirSync(state, { recursive: true });
    const bash = spawnSync("bash", ["-c", "command -v bash"], { encoding: "utf8" }).stdout.trim();
    fs.writeFileSync(scriptFile, `#!${bash}\nset -euo pipefail\n${script}\n`, { mode: 0o755 });
    const oldVideo = path.join(scratch, "old.mp4");
    const newVideo = path.join(scratch, "new.mp4");
    const overrideVideo = path.join(scratch, "override.mp4");
    for (const file of [oldVideo, newVideo, overrideVideo]) fs.writeFileSync(file, "video");
    fs.writeFileSync(path.join(state, "all.wall"), `crop\n${oldVideo}\n`);
    fs.writeFileSync(path.join(state, "Virtual-1.wall"), `crop\n${overrideVideo}\n`);
    const log = path.join(scratch, "commands.log");
    for (const [name, code] of Object.entries({
      systemctl: '#!/bin/bash\necho "systemctl $*" >> "$COMMAND_LOG"\n',
      awww: '#!/bin/bash\necho "awww $*" >> "$COMMAND_LOG"\n',
      ffprobe: '#!/bin/bash\necho video\n',
      ffmpeg: '#!/bin/bash\nprintf "poster" > "${@: -1}"\n',
    })) fs.writeFileSync(path.join(bin, name), code.replace("#!/bin/bash", `#!${bash}`), { mode: 0o755 });
    const result = spawnSync("bash", [scriptFile, "set", "all", "crop", newVideo], {
      encoding: "utf8",
      env: {
        ...process.env,
        PATH: `${bin}:${process.env.PATH}`,
        HOME: scratch,
        XDG_RUNTIME_DIR: scratch,
        XDG_STATE_HOME: path.join(scratch, "state"),
        XDG_CACHE_HOME: path.join(scratch, "cache"),
        COMMAND_LOG: log,
      },
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.readFileSync(path.join(state, "all.wall"), "utf8"), `crop\n${newVideo}\n`);
    assert.equal(fs.existsSync(path.join(state, "Virtual-1.wall")), false);
    const commands = fs.readFileSync(log, "utf8");
    const stopOverride = commands.indexOf("systemctl --user stop linux-desktop-wallpaper-video@Virtual-1.service");
    const paint = commands.lastIndexOf("awww img");
    const restartAll = commands.lastIndexOf("systemctl --user restart linux-desktop-wallpaper-video@all.service");
    assert.ok(stopOverride >= 0 && paint > stopOverride && restartAll > paint, commands);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
