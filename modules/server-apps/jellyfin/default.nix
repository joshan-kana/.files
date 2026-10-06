{ config, lib, ... }:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
  mediaRoot = "${dataRoot.path}/media";
  port = 8096;
in
{
  services.jellyfin = {
    enable = true;
    dataDir = "${appData.root}/jellyfin";
    cacheDir = "/var/cache/jellyfin";
    group = appData.group.name;
    openFirewall = false;
  };

  users.users = lib.mkIf config.services.jellyfin.enable {
    ${config.services.jellyfin.user}.extraGroups = [ dataRoot.group.name ];
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts =
    lib.optionals config.services.jellyfin.enable
      [ port ];

  systemd = lib.mkIf config.services.jellyfin.enable {
    services.jellyfin = {
      unitConfig.RequiresMountsFor = [ mediaRoot ];
      serviceConfig.ReadOnlyPaths = [ mediaRoot ];
    };

    tmpfiles.rules = [
      "d ${mediaRoot} 2770 root ${dataRoot.group.name} - -"
    ];
  };

  virtualisation.vmVariant.services.jellyfin.enable = lib.mkForce false;
}
