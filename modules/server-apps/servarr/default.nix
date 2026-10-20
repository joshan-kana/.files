{ config, lib, ... }:

let
  inherit (config.dotfiles.server.storage) dataRoot;
  mediaRoot = "${dataRoot.path}/media";
in
{
  sonarr = import ./sonarr;
  radarr = import ./radarr;
  prowlarr = import ./prowlarr;
  transmission = import ./transmission;
  bazarr = import ./bazarr;
  configarr = import ./configarr;

  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 2770 root ${dataRoot.group.name} - -"
    "d ${mediaRoot}/library 2770 root ${dataRoot.group.name} - -"
    "d ${mediaRoot}/downloads 2770 root ${dataRoot.group.name} - -"
    "d ${mediaRoot}/downloads/complete 2770 root ${dataRoot.group.name} - -"
    "d ${mediaRoot}/downloads/incomplete 2770 root ${dataRoot.group.name} - -"
    "d ${mediaRoot}/transcode 2770 root ${dataRoot.group.name} - -"
  ];

  virtualisation.vmVariant.dotfiles.scopes.serverApps.servarr.enable = lib.mkForce false;
}
