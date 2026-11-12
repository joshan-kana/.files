const assert = require("node:assert/strict");
const { test } = require("node:test");
const fs = require("node:fs");
const path = require("node:path");

const script = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../scripts/linux-desktop", name),
    "utf8",
  );
const restoreWallpaper = () => script("wallpaper-apply.sh");
const read = (name) =>
  fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/qml", name),
    "utf8",
  );

test("wallpaper apply target uses the shared persisted appearance owner", () => {
  const appearance = read("AppearancePreferences.qml");
  assert.match(
    appearance,
    /property string wallpaperTargetOutput: appearance\.runtime\.appearanceDefaults\.wallpaperTargetOutput/,
  );
  assert.match(
    appearance,
    /readonly property string wallpaperTargetOutput: effective\("wallpaperTargetOutput"\)/,
  );
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  assert.match(
    nix,
    /wallpaperTargetOutput = lib\.mkOption \{[\s\S]*?default = ""/,
  );
  assert.match(
    appearance,
    /function setWallpaperTargetOutput\(output: string\): void/,
  );
  assert.match(appearance, /storeOverride\("wallpaperTargetOutput", output\)/);
  assert.match(appearance, /saved\.sync\(\)/);
});

test("reopening gallery retains specific monitor and all-display selections", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(
    gallery,
    /outputName: appearance\.wallpaperTargetOutput\.length > 0 \? appearance\.wallpaperTargetOutput : hostOutput/,
  );
  assert.match(gallery, /function openView\(\): void \{\s*open = true;/);
  assert.doesNotMatch(gallery, /selectedOutput = hostOutput/);
  assert.match(
    gallery,
    /appearance\.setWallpaperTargetOutput\(outputChoices\[\(index \+ 1\) % outputChoices\.length\]\)/,
  );
  assert.match(gallery, /\["all"\]/);
  assert.match(gallery, /outputLabel: outputName === "all" \? "All displays"/);
});

test("saved monitor identity is not silently redirected when output disconnects", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(
    gallery,
    /outputAvailable: outputName === "all" \|\| outputChoices\.includes\(outputName\)/,
  );
  assert.match(
    gallery,
    /outputName \+ \(outputAvailable \? "" : " \(disconnected\)"\)/,
  );
  assert.match(gallery, /!outputAvailable \|\| !selectedPath\(\)/);
  assert.match(gallery, /!outputAvailable \|\| resetProcess\.running/);
  assert.match(gallery, /!open \|\| !outputAvailable/);
});

test("wallpaper operations receive the persisted target verbatim", () => {
  const gallery = read("WallpaperPanel.qml");
  assert.match(gallery, /"set", outputName, resizeMode, applyingPath/);
  assert.match(gallery, /"reset", outputName/);
  assert.match(gallery, /"current", currentRequestOutput/);
});

test("login wallpaper restoration reads the Stylix theme, not the unrelated runtime config", () => {
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  const restore = script("wallpaper-apply.sh");
  assert.match(restore, /linux-desktop\/theme\.json/);
  assert.match(restore, /wallpaper="\$\(jq -er '\.wallpaper/);
  assert.match(restore, /linux-desktop\/runtime\.json/);
  assert.match(restore, /for entry in "\$state_dir"\/\*\.wall;/);
  assert.match(restore, /cmp -s "\$entry" "\$state_dir\/all\.wall"/);
  assert.match(
    restore,
    /systemctl --user stop --no-block "linux-desktop-wallpaper-video@\$output\.service"/,
  );
  assert.match(
    restore,
    /systemctl --user start --no-block "linux-desktop-wallpaper-video@\$output\.service"/,
  );
  assert.match(
    nix,
    /Path\.PathChanged = "%h\/\.config\/linux-desktop\/theme\.json"/,
  );
});

test("full-screen video and lock-screen posters retain source resolution", () => {
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  const poster = script("wallpaper-library.sh");
  assert.match(
    poster,
    /if \[ "\$action" = poster \]; then\s+ffmpeg[^\n]*-frames:v 1 -update 1/,
  );
  assert.match(poster, /\$key\$suffix\.png/);
  assert.match(poster, /scale=380:250:force_original_aspect_ratio=decrease/);
  assert.match(
    restoreWallpaper(),
    /linux-desktop-wallpaper-library poster "\$image"/,
  );
  assert.match(poster, /still="\$\(\$0 poster "\$image"\)"/);
  assert.match(read("LockScreen.qml"), /"poster", pendingPoster/);
});

test("all-display video does not cover explicit monitor overrides", () => {
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  const player = script("wallpaper-video-from-state.sh");
  assert.match(player, /awww query/);
  assert.match(
    player,
    /if \[ -f "\$state_dir\/\$monitor\.wall" \] && \{ \[ ! -f "\$file" \] \|\| ! cmp -s "\$file" "\$state_dir\/\$monitor\.wall"; \}; then/,
  );
  assert.match(player, /mpvpaper[^\n]*"\$monitor" "\$video" &/);
  assert.doesNotMatch(player, /output='\*'/);
  assert.match(player, /wait -n/);
  assert.match(
    script("wallpaper-library.sh"),
    /systemctl --user restart linux-desktop-wallpaper-video@all\.service/,
  );
});

test("video player launches only on displays not owned by another selection", () => {
  const { spawnSync } = require("node:child_process");
  const os = require("node:os");
  const nix = fs.readFileSync(
    path.join(__dirname, "../modules/desktop/hyprland/shell/default.nix"),
    "utf8",
  );
  const player = script("wallpaper-video-from-state.sh");
  const source = player;
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "wallpaper-owner-"));
  try {
    const bin = path.join(scratch, "bin");
    const state = path.join(scratch, "state", "linux-desktop", "wallpapers");
    fs.mkdirSync(bin, { recursive: true });
    fs.mkdirSync(state, { recursive: true });
    const allVideo = path.join(scratch, "all.mp4");
    const overrideVideo = path.join(scratch, "override.mp4");
    fs.writeFileSync(allVideo, "");
    fs.writeFileSync(overrideVideo, "");
    fs.writeFileSync(path.join(state, "all.wall"), `crop\n${allVideo}\n`);
    fs.writeFileSync(
      path.join(state, "Virtual-1.wall"),
      `crop\n${overrideVideo}\n`,
    );
    fs.writeFileSync(
      path.join(bin, "awww"),
      "#!/bin/sh\nprintf ': Virtual-1: 2560x1440\\n: DP-1: 3840x2160\\n'\n",
      { mode: 0o755 },
    );
    fs.writeFileSync(
      path.join(bin, "mpvpaper"),
      '#!/bin/sh\nprintf "%s\\n" "$*" >> "$PLAYER_LOG"\nsleep 0.1\n',
      { mode: 0o755 },
    );
    const log = path.join(scratch, "players.log");
    const run = (output) => {
      fs.writeFileSync(log, "");
      const result = spawnSync(
        "bash",
        ["-euo", "pipefail", "-c", source, "wallpaper-player", output],
        {
          env: {
            ...process.env,
            PATH: `${bin}:${process.env.PATH}`,
            XDG_STATE_HOME: path.join(scratch, "state"),
            XDG_RUNTIME_DIR: scratch,
            PLAYER_LOG: log,
          },
          encoding: "utf8",
        },
      );
      assert.equal(result.error, undefined);
      return { status: result.status, players: fs.readFileSync(log, "utf8") };
    };
    let result = run("all");
    assert.equal(result.status, 1); // A mocked player exits, triggering recovery.
    assert.match(result.players, /DP-1/);
    assert.doesNotMatch(result.players, /Virtual-1|\s\*\s/);

    result = run("Virtual-1");
    assert.equal(result.status, 0);
    assert.match(result.players, /Virtual-1/);
    assert.doesNotMatch(result.players, /DP-1/);

    fs.writeFileSync(path.join(state, "Virtual-1.wall"), `crop\n${allVideo}\n`);
    result = run("all");
    assert.match(result.players, /Virtual-1/);
    assert.match(result.players, /DP-1/);
  } finally {
    fs.rmSync(scratch, { recursive: true, force: true });
  }
});
