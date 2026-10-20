{ config, pkgs, ... }:

let
  inherit (config.dotfiles.server.storage) appData;
  server = config.dotfiles.server;
  settings = {
    trashRevision = "529bd9c29eb41f38e36c14c41a137f4d5d824c99";
    sonarr = import ../sonarr/configarr.nix { inherit config; };
    radarr = import ../radarr/configarr.nix { inherit config; };
    prowlarr = import ../prowlarr/configarr.nix { inherit config; };
  };
  configFile = (pkgs.formats.yaml { tags = true; }).generate "configarr.yml" settings;
in
{
  services.configarr = {
    enable = true;
    package = pkgs.configarr;
    config = builtins.readFile configFile;
    dataDir = "${appData.root}/configarr";
    environmentFile = "${server.secretsDir}/configarr.env";
  };

  users.users.${config.services.configarr.user}.extraGroups = [ appData.group.name ];

  systemd.services.configarr = {
    environment = {
      DRY_RUN = "false";
      STOP_ON_ERROR = "true";
      TELEMETRY_ENABLED = "false";
      CONFIGARR_ENFORCE_CONFIG_VALIDATION = "true";
    };
    unitConfig.AssertPathExists = "${server.secretsDir}/configarr.env";
    after = [
      "sonarr.service"
      "radarr.service"
      "prowlarr.service"
    ];
  };
}
