# MacBook declarative setup

The MacBook configuration is `darwinConfigurations.mac` in `flake.nix`. NixOS and Darwin use one `mkHost` constructor and the same semantic registry; the constructor selects each platform's native modules. It includes Hammerspoon, yabai, shell tools, the shared theme, backups, Comin and Attic. Determinate Nix continues to manage the Nix daemon (`nix.enable = false`). Nixpkgs, Home Manager and nix-darwin manage supported Mac applications and services. Only Dropbox, GIMP and Spotify are declared as temporary Homebrew casks in the new configuration. Other existing imperatively installed applications remain in place until their migration or vendor ownership is decided. The pinned Spotify derivation currently depends on a stalled archived vendor download. Creative software, plug-ins, credentials and documents retain their existing ownership.

## Before first activation

1. Keep an up-to-date Time Machine backup and confirm the existing encrypted secrets backup is succeeding. The new Home Manager LaunchAgents use the **same** `secrets/mac` Restic repository, 15-minute backup schedule, daily maintenance, and shared retention. Do not activate them alongside the existing `com.joshankana.secrets-backup*` LaunchAgents. Preserve their original plists and bootstrap script until the declarative replacement has completed a backup and restore test.
2. Review the current `~/.hammerspoon`, `~/.config/yabai/yabairc`, and shell dotfiles. The first Home Manager activation preserves conflicting individual files with the suffix `.before-nix`; verify those backups before further changes. A pre-existing file with that suffix may require manual attention.
3. Preserve Karabiner's existing mappings and record the input-device permissions before switching. nix-darwin now owns Karabiner's native driver, helper daemons and system extension; do not activate both the existing Homebrew service and the new Nix service.
4. The new configuration also owns yabai and the Tailscale GUI. Preserve the working yabai scripting-addition setup and VPN-on-demand configuration before migration; their service and application ownership must be switched over individually. The native yabai module adds a scripting-addition launchd service and a restricted sudoers entry for its pinned executable. Confirm SIP prerequisites, sudoers contents and yabai window actions on the first boot. OpenClaw, Ollama and other vendor-managed runtime services stay untouched.
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

Subsequent manual builds and activations can use `sbld` and `sup`, which invoke `nh darwin` on macOS. Nix applications are exposed through the native nix-darwin and Home Manager application mechanisms. Keep existing `/Applications` bundles until their Nix replacements have been launched, assigned the necessary Accessibility/Input Monitoring/Screen Recording permissions, and verified with Spotlight, the Dock and URL handlers. The packaged Hammerspoon 1.1.1 app preserves its upstream code signature; recheck macOS privacy permissions after the first launch. Do not assume an app's existing permissions transfer between bundle locations.

The three declared Homebrew casks are a migration backlog, not the default installation path. This is not a count of existing imperative installations; the migration snapshot and its remaining application decisions belong in PR #251. `homebrew.onActivation.cleanup = "none"` protects existing installations during the transition. Remove the obsolete Homebrew versions only after each Nix replacement works, and keep the rollback packages and app data available.

**First-activation handover:** Before the switch, record both existing secrets-backup LaunchAgent labels and retain a restorable copy of their plist files and `backup.sh`. In the same maintenance session, unload those two existing jobs and move their original plist files out of `~/Library/LaunchAgents` into the recovery copy before activating the new Home Manager agents with the same labels. Leaving the old plists in the LaunchAgents directory risks two schedulers reloading on the next login. Verify only one instance of each schedule is loaded, then run an actual backup, `restic check`, snapshot listing, and a temporary-directory restore comparison. If the activation fails, restore the original plists and reload the original jobs immediately. Do not leave the Mac without a working backup schedule.

The Comin launchd service imports the pinned upstream Darwin module. Its executable path uses `nix.package` as a compatibility input while `nix.enable = false`; Determinate Nix retains daemon ownership. Avoid maintaining a copied Comin module for this one setting.

Comin will start managing the Mac only after this deliberate first activation. Test a manual `comin fetch` and a safe rollback before relying on future GitHub pushes. Do not merge the Mac PR or activate the new deployment jobs before native Darwin CI has passed.

## Rollback

Use nix-darwin's previous generation for a configuration rollback, and inspect the `.before-nix` backups for the original home files. The declarative configuration does not alter FileVault, SIP, Time Machine, vendor licence stores, app documents, or creative plug-ins. Keep the original files until the new setup is proven through a reboot and a real working session.

## Application ownership during migration

Bambu Studio `02.08.02.61`, PrusaSlicer `2.9.6`, Arduino IDE `2.3.10`, Cryptomator `1.19.3`, Raspberry Pi Imager `2.0.12`, Heroic `2.22.3` and Vial `0.7.5` use Nix packages built from official versioned macOS releases. The Mac's Notion `7.37.1`, Linear `1.32.4` and REAPER `7.82` packages use pinned official macOS releases to avoid replacing the installed versions with older Nixpkgs builds. ChatGPT, Beeper, Chrome, iTerm2 and Telegram remain imperatively installed until equivalent current native packages and their existing app behaviour are verified. Official bundle contents are kept unchanged. Bambu Studio, PrusaSlicer, Arduino IDE, Cryptomator, Raspberry Pi Imager and Heroic passed macOS code-signature verification. Vial's upstream x86_64 bundle is unsigned, just like the currently installed version, and needs an explicit Rosetta and Input Monitoring check. Printer connections, slicer profiles, vault mounts, serial/USB access, application updates and related integrations still require first-activation checks. KiCad and Anytype are flagged broken by the pinned Nixpkgs, and Krita's APFS installer contains symlinks its current Nix extraction path cannot safely preserve. These remain migration exceptions. OrcaSlicer Nightly stays on its existing nightly release until a reproducible, immutable asset can be pinned without silently replacing it with stable. Autodesk Fusion remains installed through Autodesk's `webdeploy` service and licensing system; a managed shortcut alone would not make that installation declarative.

Arc `1.168.0` (build `88413`) and QMK Toolbox `0.3.4` use pinned, code-signature-verified official macOS ZIP releases. Stremio `5.1.26` is deliberately not Nix-managed: the extracted DMG app fails verification of its sealed bundle, even though the current installed application verifies. Preserve its existing installation until a packaging method keeps the signature valid.

Hammerspoon no longer watches `~/.hammerspoon` for file changes. Home Manager tracks the Lua files and calls Hammerspoon's IPC reload command **after** a successful file-link activation when those contents actually change. An unrelated rebuild does not reload it; editing a file outside Nix also does not automatically trigger a reload. If Hammerspoon is not running, the next launch reads the new files.

Mac and NixOS hosts are listed in the same `hostSpecs` set in `flake.nix`; the shared `mkHost` uses the same named nixpkgs, Home Manager and Stylix inputs as the existing NixOS hosts, selecting native platform interfaces. Mac application and CLI implementations live in the shared `modules/desktop-apps` and `modules/cli` semantic scopes, with desktop and OrbStack integrations under `modules/desktop` and `modules/virtualisation`. The Mac host retains only its actual machine-specific settings and shell overrides. Hammerspoon intentionally retains its own Framer and Tokyo Night themes; a previously generated but unused Stylix palette has been removed to avoid implying that the UI consumes it. The existing live `~/.hammerspoon/*.lua` sources, including scratchpad and quick-access workspace bindings, are copied into the shared Hammerspoon module and checked with default StyLua/LuaCheck settings; the yabai CLI calls use the Nix-managed system binary. It does not install deprecated window-manager trials simply because they remain in Homebrew receipts. Do not uninstall existing app bundles or transfer permissions in bulk; replace each application only after checking its settings, documents, extensions and launch behaviour. The installed application and formula inventory, including deferred migrations, is recorded in PR #251.

## Creative software recovery

Ableton Live, DAWs, audio plug-ins, instruments, their proprietary installers, presets, sample libraries, and licence activations remain vendor-managed. Their binary installers are retained in Dropbox, and Time Machine covers normal local application and library state. Reinstall from trusted vendor downloads or the saved installers, then restore user presets and projects from their appropriate backups and reactivate licences using the vendor's supported process. Do not put plug-in binaries, installers, authorisation data, or sample libraries into `.files` or the Nix store.

For a reliable restore, periodically verify that the Dropbox installer archive contains the actual versions required by existing projects and that Time Machine covers local application settings and plug-in directories. Test representative Ableton project recovery rather than assuming that copying an `.app` bundle restores everything.

## Intentionally unmanaged

AeroSpace, skhd, Amethyst, komorebi-for-mac, AltTab, and the unmaintained Whisky application are deliberately excluded. VS Code uses Settings Sync. Raycast's old application-switching hotkeys are superseded by Hammerspoon. Application profiles, authentications, creative plug-ins, and any old configuration files remain untouched until explicitly cleaned up.
