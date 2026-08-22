{
  config,
  lib,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  dataRoot = serverCfg.storage.dataRoot.path;
  cacheRoot = "${dataRoot}/nix-cache";
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

      # Keep cache retention independent from ordinary Nix GC. Retention can be
      # enabled later per cache after real Vault usage has been measured.
      garbage-collection.interval = "0 seconds";
    };
  };

  # The upstream Attic module uses DynamicUser by default. A stable local user
  # lets us own the external Vault directory without placing cache data under
  # /var/lib or relying on runtime-only user IDs.
  systemd.services.atticd = {
    after = [ "attic-cache-storage.service" ];
    requires = [ "attic-cache-storage.service" ];
    unitConfig.AssertPathIsMountPoint = dataRoot;
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      ReadWritePaths = [ cacheRoot ];
    };
  };

  # Do not use tmpfiles for this path: tmpfiles may run before ZFS is mounted
  # and could otherwise create the cache directory on the SD-card rootfs.
  systemd.services.attic-cache-storage = {
    description = "Prepare Attic storage on the Vault";
    after = [ "zfs-mount.service" ];
    before = [ "atticd.service" ];
    requiredBy = [ "atticd.service" ];
    unitConfig.AssertPathIsMountPoint = dataRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 0750 -o atticd -g atticd ${lib.escapeShellArg cacheRoot}
      ${pkgs.coreutils}/bin/install -d -m 0750 -o atticd -g atticd ${lib.escapeShellArg cacheStorage}
    '';
  };

  # Attic listens on all local addresses so both LAN and Tailscale clients can
  # reach it, while the firewall restricts ingress to those interfaces only.
  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts = [ cachePort ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cachePort ];
}
