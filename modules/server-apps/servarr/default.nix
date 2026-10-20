{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
  mediaRoot = "${dataRoot.path}/media";
  downloads = "${mediaRoot}/downloads";
  transmissionCredentials = "${server.secretsDir}/transmission.json";
  sharedGroups = [
    appData.group.name
    dataRoot.group.name
  ];
in
{
  services = {
    sonarr = {
      enable = true;
      dataDir = "${appData.root}/sonarr";
      settings.server.bindaddress = "*";
    };

    radarr = {
      enable = true;
      dataDir = "${appData.root}/radarr";
      settings.server.bindaddress = "*";
    };

    prowlarr = {
      enable = true;
      dataDir = "${appData.root}/prowlarr";
      settings.server.bindaddress = "*";
    };

    bazarr = {
      enable = true;
      dataDir = "${appData.root}/bazarr";
      settings.general.ip = "0.0.0.0";
    };

    transmission = {
      enable = true;
      package = pkgs.transmission_4;
      home = "${appData.root}/transmission";
      group = dataRoot.group.name;
      credentialsFile = transmissionCredentials;
      downloadDirPermissions = "2770";
      settings = {
        download-dir = "${downloads}/complete";
        incomplete-dir = "${downloads}/incomplete";
        rpc-bind-address = "0.0.0.0";
        rpc-authentication-required = true;
        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
        umask = "002";
      };
    };
  };

  users.users = {
    ${config.services.sonarr.user}.extraGroups = sharedGroups;
    ${config.services.radarr.user}.extraGroups = sharedGroups;
    ${config.services.bazarr.user}.extraGroups = sharedGroups;
    ${config.services.transmission.user}.extraGroups = sharedGroups;
  };

  systemd = {
    services =
      lib.genAttrs
        [
          "sonarr"
          "radarr"
          "prowlarr"
          "bazarr"
          "transmission"
          "transmission-setup"
        ]
        (name: {
          unitConfig.RequiresMountsFor = [ mediaRoot ];
          requires = lib.optionals (name == "transmission") [
            "transmission-setup.service"
            "transmission-credentials.service"
          ];
          after = lib.optionals (name == "transmission") [
            "transmission-setup.service"
            "transmission-credentials.service"
          ];
          serviceConfig =
            lib.optionalAttrs
              (builtins.elem name [
                "sonarr"
                "radarr"
                "bazarr"
              ])
              {
                UMask = lib.mkForce "0002";
              };
        })
      // {
        transmission-credentials = {
          description = "Initialize Transmission RPC credentials";
          serviceConfig.Type = "oneshot";
          script = ''
            set -eu
            umask 077
            install -d -m 0700 '${server.secretsDir}'
            if [ ! -e '${transmissionCredentials}' ]; then
              password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
              file="$(mktemp '${server.secretsDir}/.transmission.XXXXXXXX')"
              trap 'rm -f "$file"' EXIT
              printf '{"rpc-username":"media","rpc-password":"%s"}\n' "$password" > "$file"
              mv -n "$file" '${transmissionCredentials}'
            fi
          '';
        };
      };

    tmpfiles.rules = [
      "d ${mediaRoot} 2770 root ${dataRoot.group.name} - -"
      "d ${mediaRoot}/library 2770 root ${dataRoot.group.name} - -"
      "d ${downloads} 2770 root ${dataRoot.group.name} - -"
      "d ${downloads}/complete 2770 root ${dataRoot.group.name} - -"
      "d ${downloads}/incomplete 2770 root ${dataRoot.group.name} - -"
      "d ${mediaRoot}/transcode 2770 root ${dataRoot.group.name} - -"
      "d ${appData.root}/sonarr 0700 ${config.services.sonarr.user} ${config.services.sonarr.group} - -"
      "d ${appData.root}/prowlarr 0700 root root - -"
    ];
  };

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    config.services.sonarr.settings.server.port
    config.services.radarr.settings.server.port
    config.services.prowlarr.settings.server.port
    config.services.bazarr.settings.general.port
    config.services.transmission.settings.rpc-port
  ];

  virtualisation.vmVariant.dotfiles.scopes.serverApps.servarr.enable = lib.mkForce false;
}
