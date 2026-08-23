{
  config,
  lib,
  ...
}:

let
  serverCfg = config.dotfiles.server;
  cacheRoot = "/var/lib/atticd";
  cachePort = 8080;
  cacheHost = config.networking.hostName;
in
{
  users.groups.atticd = { };
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };

  services.atticd = {
    enable = true;
    environmentFile = "${serverCfg.secretsDir}/attic.env";
    settings = {
      listen = "0.0.0.0:${toString cachePort}";
      api-endpoint = "http://${cacheHost}:${toString cachePort}/";
      allowed-hosts = [
        cacheHost
        "${cacheHost}:${toString cachePort}"
      ];
    };
  };

  systemd.services.atticd = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig.AssertPathIsMountPoint = cacheRoot;
    serviceConfig.DynamicUser = lib.mkForce false;
  };

  networking.firewall.interfaces.${serverCfg.lan.interface}.allowedTCPPorts = [ cachePort ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cachePort ];
}
