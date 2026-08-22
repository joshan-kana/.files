{
  config,
  lib,
  pkgs,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  dataRoot = serverCfg.storage.dataRoot.path;
  pool = serverCfg.storage.dataRoot.poolName;
  cacheDataset = "${pool}/nix-cache";
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

  # The upstream Attic module uses DynamicUser by default. A persistent local
  # user lets the separately-mounted Vault dataset have stable ownership.
  systemd.services.atticd = {
    after = [ "attic-cache-storage.service" ];
    requires = [ "attic-cache-storage.service" ];
    unitConfig.AssertPathIsMountPoint = cacheRoot;
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      ReadWritePaths = [ cacheRoot ];
    };
  };

  # The cache is deliberately a sibling of vault/data, not a child ZFS dataset
  # of it. Sanoid snapshots vault/data recursively, so this keeps disposable
  # cache churn out of long-lived Vault snapshots. Dataset creation remains a
  # one-time explicit storage operation; normal activation only verifies it.
  systemd.services.attic-cache-storage = {
    description = "Verify the Attic Vault dataset";
    after = [ "zfs-mount.service" ];
    before = [ "atticd.service" ];
    requiredBy = [ "atticd.service" ];
    unitConfig.AssertPathIsMountPoint = cacheRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      actual_dataset="$(${pkgs.zfs}/bin/zfs list -H -o name ${lib.escapeShellArg cacheDataset} 2>/dev/null || true)"
      if [[ "$actual_dataset" != ${lib.escapeShellArg cacheDataset} ]]; then
        echo "Attic cache dataset ${cacheDataset} does not exist" >&2
        exit 1
      fi

      actual_mount="$(${pkgs.zfs}/bin/zfs get -H -o value mountpoint ${lib.escapeShellArg cacheDataset})"
      if [[ "$actual_mount" != ${lib.escapeShellArg cacheRoot} ]]; then
        echo "Attic cache dataset must be mounted at ${cacheRoot}; got $actual_mount" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/install -d -m 0750 -o atticd -g atticd ${lib.escapeShellArg cacheStorage}
      ${pkgs.coreutils}/bin/chown atticd:atticd ${lib.escapeShellArg cacheRoot}
      ${pkgs.coreutils}/bin/chmod 0750 ${lib.escapeShellArg cacheRoot}
    '';
  };

  # Attic listens on all local addresses so both LAN and Tailscale clients can
  # reach it, while the firewall restricts ingress to those interfaces only.
  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts = [ cachePort ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cachePort ];
}
