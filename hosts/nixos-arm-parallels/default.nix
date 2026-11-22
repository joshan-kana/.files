{
  editScope,
  extendScope,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

let
  login = config.dotfiles.users.primary.name;
  home = config.users.users.${login}.home;
  shellAccess = pkgs.writeShellScript "chatgpt-shell-parallels-command" ''
    set -eu
    : "''${SSH_ORIGINAL_COMMAND:?a remote command is required}"

    # SSH agent forwarding is enabled only for the separately approved run0 path.
    if [ -n "''${SSH_AUTH_SOCK:-}" ]; then
      # An arbitrary forwarded agent is insufficient to escape the sandbox.
      # Require a signature from the existing run0 authentication key.
      ${pkgs.openssh}/bin/ssh-add -T /etc/elevation-authorized-key >/dev/null 2>&1
      exec ${pkgs.bash}/bin/bash -c "$SSH_ORIGINAL_COMMAND"
    fi

    # The ordinary shell retains the normal account and writable workspaces,
    # but cannot inherit its SSH credentials or escape via the user manager.
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    exec ${pkgs.systemd}/bin/systemd-run --user --quiet --wait --pipe --collect \
      --property=NoNewPrivileges=yes \
      --property=PrivateTmp=yes \
      --property=PrivatePIDs=yes \
      --property=ProtectSystem=full \
      --property='InaccessiblePaths=${home}/.ssh ${home}/.secrets /run/user' \
      ${pkgs.bash}/bin/bash -c "$SSH_ORIGINAL_COMMAND"
  '';
in

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  hardware = import ./hardware.nix;

  system = extendScope moduleRegistry.system {
    parallels = _: {
      systemd.user.services.prlcc.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "2s";
      };

  networking = editScope moduleRegistry.networking {
    ssh = { config, ... }: {
      users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsiQZEG5WB92zEubOX4InNHN4ev8byz2KBwzGLzMWPA chatgpt-shell-nixos-arm-parallels"
      ];
    };
  };

  desktopApps = editScope moduleRegistry.desktopApps {
    kitty = _: {
      home = _: {
        programs.kitty.package = pkgs.kitty-virgl;
      };
    };
  };

  users.users.${config.dotfiles.users.primary.name}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com"
    ''restrict,agent-forwarding,command="${shellAccess}" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJsiQZEG5WB92zEubOX4InNHN4ev8byz2KBwzGLzMWPA chatgpt-shell-nixos-arm-parallels''
  ];

  systemd.tmpfiles.rules = [
    "f+ /etc/elevation-authorized-key 0444 root root - ssh-ed25519\\x20AAAAC3NzaC1lZDI1NTE5AAAAIGRtvQBAj3/3cJYqS4KosghtI5fsh9poh3q+LIfFL8KR\\x20joshan@nixos-arm-parallels-sudo\\n"
  ];

  boot = {
    initrd.kernelModules = [ "virtio_gpu" ];
    kernelPackages = pkgs.linuxPackages_latest;
  };
}
