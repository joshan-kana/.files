# MacBook declarative setup

The `mac` Darwin host composes the same semantic scopes as the NixOS fleet. Portable CLI tools, system commands, the theme registry, Nix/Attic policy, backups, and Comin deployment reuse the shared modules; Linux-only implementation details contribute no Darwin configuration. Hammerspoon, yabai, and selected macOS preferences use native host integration. Determinate Nix continues to own the installed Nix daemon (`nix.enable = false`). Homebrew installs selected native applications; no creative applications, plug-ins, user accounts, credentials, or document libraries are imported into the Nix store.

## Before first activation

1. Keep an up-to-date Time Machine backup and confirm the existing encrypted secrets backup is succeeding. The new Home Manager LaunchAgents use the **same** `secrets/mac` Restic repository, 15-minute backup schedule, daily maintenance, and shared retention. Do not activate them alongside the existing `com.joshankana.secrets-backup*` LaunchAgents. Preserve their original plists and bootstrap script until the declarative replacement has completed a backup and restore test.
2. Review the current `~/.hammerspoon`, `~/.config/yabai/yabairc`, and shell dotfiles. The first Home Manager activation preserves conflicting individual files with the suffix `.before-nix`; verify those backups before further changes. A pre-existing file with that suffix may require manual attention.
3. Keep Karabiner's device-specific mappings and GUI state application-managed until its write behaviour and profile ownership have been tested. Hammerspoon uses its existing modifier aliases and yabai backend.
4. Leave existing yabai, OpenClaw, Ollama, Tailscale, and other hand-installed services running. This configuration does not replace those app-managed processes or their network bindings.
5. Confirm the runtime Restic password and rclone configuration files exist under `~/Library/Application Support/SecretsBackup`, and `~/.secrets` is private. The existing encrypted backup repository remains authoritative; never initialise a second one.
6. Provision `~/.secrets/comin-github` (read-only repository deploy key) and `~/.secrets/attic-token` (narrowly scoped cache-upload credential) through the existing secret recovery process. Do **not** embed them in the flake or deploy before they are available. The declarative Comin and Attic launchd jobs expect these runtime credentials.
7. Ensure the server-only ntfy and Attic endpoints are reachable from the Mac on the LAN, and check away-from-home Tailscale fallback. Comin event subscription is the fast path; its existing five-minute reconciliation fetch handles missed events.
8. The shared networking scope now owns the native macOS SSH service with key-only authentication. Arrange physical-console access before the first switch; verify the server can still SSH to the Mac afterward before removing the original SSH configuration.

## Evaluate and build

Run from the `.files` repository:

```sh
nix eval --raw .#darwinConfigurations.mac.config.system.build.toplevel.drvPath
nix build --no-link .#darwinConfigurations.mac.system
nix flake check
```

The initial bootstrap activation, after reviewing the generated configuration, is:

```sh
sudo nix run github:nix-darwin/nix-darwin#darwin-rebuild -- switch --flake "$HOME/.files#mac"
```

Subsequent manual builds and activations can use `sbld` and `sup`, which invoke `nh darwin` on macOS. Review any conflicting symlinks and existing Homebrew-managed packages before switching.

**First-activation handover:** Before the switch, record both existing secrets-backup LaunchAgent labels and retain a restorable copy of their plist files and `backup.sh`. In the same maintenance session, unload those two existing jobs and move their original plist files out of `~/Library/LaunchAgents` into the recovery copy before activating the new Home Manager agents with the same labels. Leaving the old plists in the LaunchAgents directory risks two schedulers reloading on the next login. Verify only one instance of each schedule is loaded, then run an actual backup, `restic check`, snapshot listing, and a temporary-directory restore comparison. If the activation fails, restore the original plists and reload the original jobs immediately. Do not leave the Mac without a working backup schedule.

Comin will start managing the Mac only after this deliberate first activation. Test a manual `comin fetch` and a safe rollback before relying on future GitHub pushes. Do not merge the Mac PR or activate the new deployment jobs before native Darwin CI has passed.

## Rollback

Use nix-darwin's previous generation for a configuration rollback, and inspect the `.before-nix` backups for the original home files. The declarative configuration does not alter FileVault, SIP, Time Machine, vendor licence stores, app documents, or creative plug-ins. Keep the original files until the new setup is proven through a reboot and a real working session.

## Creative software recovery

Ableton Live, DAWs, audio plug-ins, instruments, their proprietary installers, presets, sample libraries, and licence activations remain vendor-managed. Their binary installers are retained in Dropbox, and Time Machine covers normal local application and library state. Reinstall from trusted vendor downloads or the saved installers, then restore user presets and projects from their appropriate backups and reactivate licences using the vendor's supported process. Do not put plug-in binaries, installers, authorisation data, or sample libraries into `.files` or the Nix store.

For a reliable restore, periodically verify that the Dropbox installer archive contains the actual versions required by existing projects and that Time Machine covers local application settings and plug-in directories. Test representative Ableton project recovery rather than assuming that copying an `.app` bundle restores everything.

## Intentionally unmanaged

AeroSpace, skhd, Amethyst, komorebi-for-mac, and AltTab are old trials; they are deliberately not included. VS Code uses Settings Sync. Raycast's old application-switching hotkeys are superseded by Hammerspoon. Application profiles, authentications, creative plug-ins, and any old configuration files remain untouched until explicitly cleaned up.
