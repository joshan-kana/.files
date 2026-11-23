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

    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"

    validRequest() {
      [[ "$1" =~ ^[0-9a-f]{32}$ ]]
    }

    command="$SSH_ORIGINAL_COMMAND"
    unit=()
    case "$command" in
      "chatgpt-shell-run "*)
        payload="''${command#chatgpt-shell-run }"
        request="''${payload%% *}"
        validRequest "$request" && [ "$payload" != "$request" ] || exit 2
        command="''${payload#* }"
        [ -n "$command" ] || exit 2
        unit=(--unit="chatgpt-shell-$request")
        ;;
      "chatgpt-shell-cancel "*)
        payload="''${command#chatgpt-shell-cancel }"
        request="''${payload%% *}"
        signal="''${payload#* }"
        validRequest "$request" || exit 2
        [ "$signal" = KILL ] || exit 2
        # A kill before systemd starts the unit's main process can succeed
        # without stopping the command. Wait only for this specific unit.
        for ((attempt = 0; attempt < 50; attempt++)); do
          mainpid="$(${pkgs.systemd}/bin/systemctl --user show \
            --property=MainPID --value "chatgpt-shell-$request.service" 2>/dev/null || :)"
          if [[ "$mainpid" =~ ^[1-9][0-9]*$ ]]; then
            exec ${pkgs.systemd}/bin/systemctl --user kill --kill-whom=all \
              --signal=KILL "chatgpt-shell-$request.service"
          fi
          ${pkgs.coreutils}/bin/sleep 0.1
        done
        exit 1
        ;;
    esac

    # The private PID namespace isolates peer sessions. A named unit still
    # permits an authenticated request-specific interruption.
    exec ${pkgs.systemd}/bin/systemd-run --user --quiet --wait --pipe --collect \
      "''${unit[@]}" \
      --property=NoNewPrivileges=yes \
      --property=PrivateTmp=yes \
      --property=PrivatePIDs=yes \
      --property=ProtectSystem=full \
      --property='InaccessiblePaths=${home}/.ssh ${home}/.secrets /run/user' \
      ${pkgs.bash}/bin/bash -c "$command"
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
