{
  config,
  lib,
  ...
}:

let
  inherit (config.dotfiles) server;
  cacheRoot = "/var/lib/atticd";
  cachePort = 8080;
  atticSecret = "${server.secretsDir}/attic.env";
  cacheHost = server.lan.serverIp;
in
{
  users.groups.atticd = { };
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };

  services.atticd = {
    enable = true;
    environmentFile = atticSecret;
    settings = {
      listen = "0.0.0.0:${toString cachePort}";
      api-endpoint = "http://${cacheHost}:${toString cachePort}/";
      allowed-hosts = [
        cacheHost
        "${cacheHost}:${toString cachePort}"
      ];
      chunking = {
        nar-size-threshold = 0;
        min-size = 16 * 1024;
        avg-size = 64 * 1024;
        max-size = 256 * 1024;
      };
    };
  };

  systemd.services.atticd = {
    after = [ "zfs-mount.service" ];
    requires = [ "zfs-mount.service" ];
    unitConfig = {
      AssertPathExists = atticSecret;
      AssertPathIsMountPoint = cacheRoot;
    };
    serviceConfig.DynamicUser = lib.mkForce false;
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [ cachePort ];
}
