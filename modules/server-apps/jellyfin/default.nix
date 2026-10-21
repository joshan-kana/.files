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

  users.users.${config.services.jellyfin.user}.extraGroups = [ dataRoot.group.name ];

  networking.firewall.interfaces = {
    ${server.lan.interface}.allowedTCPPorts = [ port ];
    docker0.allowedTCPPorts = [ port ];
  };

  systemd = {
    services.jellyfin.unitConfig.RequiresMountsFor = [ mediaRoot ];

    tmpfiles.rules = [
      "d ${mediaRoot} 2770 root ${dataRoot.group.name} - -"
    ];
  };

  virtualisation.vmVariant.dotfiles.scopes.serverApps.jellyfin.enable = lib.mkForce false;
}
