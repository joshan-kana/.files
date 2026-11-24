{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles.server.storage) appData;
  worker = "agent-workspaces";
  stateRoot = "${appData.root}/${worker}";
  runtimeRoot = "/run/${worker}";
  workerEnvironment = {
    HOME = stateRoot;
    HC_SESSION = "chatgpt-shell";
    XDG_CONFIG_HOME = "${stateRoot}/.config";
    XDG_RUNTIME_DIR = runtimeRoot;
    XDG_STATE_HOME = "${stateRoot}/.local/state";
  };
  forcedEnvironment = lib.concatStringsSep " " (
    lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") workerEnvironment
  );
in
{
  environment.systemPackages = [ pkgs.herdr-core ];

  users.groups.${worker} = { };
  users.users.${worker} = {
    isSystemUser = true;
    group = worker;
    home = stateRoot;
    shell = pkgs.bashInteractive;
    # SSH clients may connect only through the native Herdr protocol.
    openssh.authorizedKeys.keys = [
      ''restrict,command="${pkgs.coreutils}/bin/env ${forcedEnvironment} ${pkgs.herdr-core}/bin/hc connect --session ${lib.escapeShellArg workerEnvironment.HC_SESSION}" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGMZdbT05P/naiv07J32DxHDOR5A1z8F9jijeBrDkXWV joshankana@gmail.com''
    ];
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.user === "${worker}")
        return polkit.Result.NO;
    });
  '';

  systemd.tmpfiles.rules = [
    # The worker can traverse the shared root, not list or edit other applications.
    "a+ ${appData.root} - - - - u:${worker}:--x"
    "d ${stateRoot} 0700 ${worker} ${worker} - -"
  ];

  systemd.services.agent-workspaces = {
    description = "Persistent agent workspaces (Herdr Core)";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bash
      coreutils
      curl
      diffutils
      file
      findutils
      gawk
      gh
      git
      gnugrep
      gnupatch
      gnused
      herdr-core
      iproute2
      jq
      nix
      openssh
      procps
      psmisc
      python3
      ripgrep
      rsync
      systemd
      util-linux
    ];
    environment = workerEnvironment;
    unitConfig.RequiresMountsFor = [ stateRoot ];
    serviceConfig = {
      Type = "simple";
      User = worker;
      Group = worker;
      WorkingDirectory = stateRoot;
      ExecStart = "${pkgs.herdr-core}/bin/herdr-core serve";
      Restart = "always";
      RestartSec = "2s";
      RuntimeDirectory = worker;
      RuntimeDirectoryMode = "0700";
      ReadWritePaths = [ stateRoot ];
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
