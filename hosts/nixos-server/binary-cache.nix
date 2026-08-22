{
  config,
  lib,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  cacheRoot = "${serverCfg.storage.dataRoot.path}/nix-cache";
  cacheStorage = "${cacheRoot}/storage";
  cachePort = 8080;
in
{
  users.groups.atticd = { };
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };

  environment.systemPackages = [ pkgs.attic-client ];

  services.atticd = {
    enable = true;
    environmentFile = "${serverCfg.secretsDir}/attic.env";
    settings = {
      listen = "0.0.0.0:${toString cachePort}";
      database.url = "sqlite://${cacheRoot}/server.db?mode=rwc";
      storage = {
        type = "local";
        path = cacheStorage;
      };
    };
  };

  # Keep cache data off the SD card if the dedicated Vault dataset is absent.
  # A small root-run oneshot prepares ownership before the sandboxed Attic
  # service starts; Attic itself remains the normal upstream NixOS module.
  systemd.services.atticd = {
    after = [ "attic-cache-storage.service" ];
    requires = [ "attic-cache-storage.service" ];
    unitConfig.AssertPathIsMountPoint = cacheRoot;
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      ReadWritePaths = [ cacheRoot ];
    };
  };

  systemd.services.attic-cache-storage = {
    description = "Prepare Attic cache storage";
    after = [ "zfs-mount.service" ];
    before = [ "atticd.service" ];
    requiredBy = [ "atticd.service" ];
    unitConfig.AssertPathIsMountPoint = cacheRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 -o atticd -g atticd ${lib.escapeShellArg cacheStorage}
      ${pkgs.coreutils}/bin/chown atticd:atticd ${lib.escapeShellArg cacheRoot}
      ${pkgs.coreutils}/bin/chmod 0750 ${lib.escapeShellArg cacheRoot}
    '';
  };

  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts = [ cachePort ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cachePort ];
}
