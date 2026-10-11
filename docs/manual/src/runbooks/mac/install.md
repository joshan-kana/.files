# MacBook declarative setup

The `mac` Darwin host manages the shared CLI profile, selected macOS preferences, Hammerspoon, and yabai configuration. Determinate Nix continues to own the installed Nix daemon (`nix.enable = false`). Homebrew installs selected native applications; no creative applications, plug-ins, user accounts, credentials, or document libraries are imported into the Nix store.

## Before first activation

1. Keep an up-to-date Time Machine backup and confirm the existing encrypted secrets backup is succeeding. Do not stop the current `com.joshankana.secrets-backup*` LaunchAgents. They already use the shared per-host Restic/Dropbox recovery model. Migrating their scheduler into nix-darwin must be a separate, tested cutover, not a second simultaneously active backup job.
2. Review the current `~/.hammerspoon`, `~/.config/yabai/yabairc`, and shell dotfiles. The first Home Manager activation preserves conflicting individual files with the suffix `.before-nix`; verify those backups before further changes. A pre-existing file with that suffix may require manual attention.
3. Keep Karabiner's device-specific mappings and GUI state application-managed until its write behaviour and profile ownership have been tested. Hammerspoon uses its existing modifier aliases and yabai backend.
4. Leave existing yabai, OpenClaw, Ollama, Tailscale, and other hand-installed LaunchAgents running. This first stage does not take over their lifecycle or alter their network bindings.

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

Subsequent activations can use `sudo darwin-rebuild switch --flake "$HOME/.files#mac"`. Review any conflicting symlinks and existing Homebrew-managed packages before switching. Do not run two window-manager services or two backup schedules simultaneously.

## Rollback

Use nix-darwin's previous generation for a configuration rollback, and inspect the `.before-nix` backups for the original home files. The declarative configuration does not alter FileVault, SIP, Time Machine, vendor licence stores, app documents, or creative plug-ins. Keep the original files until the new setup is proven through a reboot and a real working session.

## Creative software recovery

Ableton Live, DAWs, audio plug-ins, instruments, their proprietary installers, presets, sample libraries, and licence activations remain vendor-managed. Their binary installers are retained in Dropbox, and Time Machine covers normal local application and library state. Reinstall from trusted vendor downloads or the saved installers, then restore user presets and projects from their appropriate backups and reactivate licences using the vendor's supported process. Do not put plug-in binaries, installers, authorisation data, or sample libraries into `.files` or the Nix store.

For a reliable restore, periodically verify that the Dropbox installer archive contains the actual versions required by existing projects and that Time Machine covers local application settings and plug-in directories. Test representative Ableton project recovery rather than assuming that copying an `.app` bundle restores everything.

## Intentionally unmanaged

AeroSpace, skhd, Amethyst, komorebi-for-mac, and AltTab are old trials; they are deliberately not included. VS Code uses Settings Sync. Raycast's old application-switching hotkeys are superseded by Hammerspoon. Application profiles, authentications, creative plug-ins, and any old configuration files remain untouched until explicitly cleaned up.
