{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData dataRoot;
  mediaRoot = "${dataRoot.path}/media";
  transmissionCredentials = "${server.secretsDir}/transmission.json";

in
rec {
  sonarr = {
    __functor = _: _: {
      services.sonarr = {
        dataDir = "${appData.root}/sonarr";
        settings.server.bindaddress = "*";
      };

      users.users.${config.services.sonarr.user}.extraGroups = [
        appData.group.name
        dataRoot.group.name
      ];

      systemd = {
        services.sonarr = {
          unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
          serviceConfig.UMask = lib.mkForce "0002";
        };
        tmpfiles.rules = [
          "d ${appData.root}/sonarr 0700 ${config.services.sonarr.user} ${config.services.sonarr.group} - -"
        ];
      };

      networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
        config.services.sonarr.settings.server.port
      ];
    };

    configArr = {
      main = {
        base_url = "http://127.0.0.1:${toString config.services.sonarr.settings.server.port}";
        api_key."!env" = "SONARR_API_KEY";
        custom_formats = [
          {
            trash_ids = [ "505d871304820ba7106b693be6fe4a9e" ]; # HDR
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 500;
              }
            ];
          }
          {
            trash_ids = [ "7c3a61a9c6cb04f52f1544be6d44a026" ]; # DV Boost
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 1000;
              }
            ];
          }
        ];
        quality_profiles = [
          {
            name = "Ultra-HD";
            upgrade = {
              allowed = true;
              until_quality = "Bluray-2160p";
              until_score = 1000;
            };
            min_format_score = 0;
            qualities = [
              { name = "Bluray-2160p"; }
              {
                name = "WEB 2160p";
                qualities = [
                  "WEBDL-2160p"
                  "WEBRip-2160p"
                ];
              }
              { name = "HDTV-2160p"; }
            ];
          }
        ];
        download_clients = {
          data = [
            {
              name = "Transmission";
              type = "transmission";
              enable = true;
              fields = {
                host = "localhost";
                port = config.services.transmission.settings.rpc-port;
                username = "media";
                password."!env" = "TRANSMISSION_RPC_PASSWORD";
                tv_category = "sonarr";
              };
            }
          ];
          delete_unmanaged.enabled = false;
        };
      };
    };
  };

  radarr = {
    __functor = _: _: {
      services.radarr = {
        dataDir = "${appData.root}/radarr";
        settings.server.bindaddress = "*";
      };

      users.users.${config.services.radarr.user}.extraGroups = [
        appData.group.name
        dataRoot.group.name
      ];

      systemd.services.radarr = {
        unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
        serviceConfig.UMask = lib.mkForce "0002";
      };

      networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
        config.services.radarr.settings.server.port
      ];
    };

    configArr = {
      main = {
        base_url = "http://127.0.0.1:${toString config.services.radarr.settings.server.port}";
        api_key."!env" = "RADARR_API_KEY";
        custom_formats = [
          {
            trash_ids = [ "493b6d1dbec3c3364c59d7607f7e3405" ]; # HDR
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 500;
              }
            ];
          }
          {
            trash_ids = [ "b337d6812e06c200ec9a2d3cfa9d20a7" ]; # DV Boost
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 1000;
              }
            ];
          }
        ];
        quality_profiles = [
          {
            name = "Ultra-HD";
            language = "Original";
            upgrade = {
              allowed = true;
              until_quality = "Remux-2160p";
              until_score = 1000;
            };
            min_format_score = 0;
            qualities = [
              { name = "Remux-2160p"; }
              { name = "Bluray-2160p"; }
              {
                name = "WEB 2160p";
                qualities = [
                  "WEBDL-2160p"
                  "WEBRip-2160p"
                ];
              }
              { name = "HDTV-2160p"; }
            ];
          }
        ];
        download_clients = {
          data = [
            {
              name = "Transmission";
              type = "transmission";
              enable = true;
              fields = {
                host = "localhost";
                port = config.services.transmission.settings.rpc-port;
                username = "media";
                password."!env" = "TRANSMISSION_RPC_PASSWORD";
                movie_category = "radarr";
              };
            }
          ];
          delete_unmanaged.enabled = false;
        };
      };
    };
  };

  prowlarr = {
    __functor = _: _: {
      services.prowlarr = {
        dataDir = "${appData.root}/prowlarr";
        settings.server.bindaddress = "*";
      };

      systemd = {
        services.prowlarr = {
          serviceConfig.StateDirectoryMode = "0700";
        };
        # Prowlarr's DynamicUser owns this directory; tmpfiles must not reset it.
        tmpfiles.settings."10-prowlarr"."${appData.root}/prowlarr".d = {
          user = lib.mkForce "-";
          group = lib.mkForce "-";
          mode = lib.mkForce "-";
        };
      };

      networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
        config.services.prowlarr.settings.server.port
      ];
    };

    configArr = {
      main = {
        base_url = "http://127.0.0.1:${toString config.services.prowlarr.settings.server.port}";
        api_key."!env" = "PROWLARR_API_KEY";
        indexers = {
          data = [
            {
              name = "Knaben";
              definition = "Knaben";
              enable = true;
            }
            {
              name = "LimeTorrents";
              definition = "limetorrents";
              enable = true;
            }
            {
              name = "Nyaa.si";
              definition = "nyaasi";
              enable = true;
            }
            {
              name = "YTS";
              definition = "yts";
              enable = true;
            }
          ];
          delete_unmanaged.enabled = false;
        };
        applications = {
          data = [
            {
              name = "Sonarr";
              type = "Sonarr";
              sync_level = "fullSync";
              fields = {
                prowlarrUrl = "http://localhost:${toString config.services.prowlarr.settings.server.port}";
                baseUrl = "http://localhost:${toString config.services.sonarr.settings.server.port}";
                apiKey."!env" = "SONARR_API_KEY";
              };
            }
            {
              name = "Radarr";
              type = "Radarr";
              sync_level = "fullSync";
              fields = {
                prowlarrUrl = "http://localhost:${toString config.services.prowlarr.settings.server.port}";
                baseUrl = "http://localhost:${toString config.services.radarr.settings.server.port}";
                apiKey."!env" = "RADARR_API_KEY";
              };
            }
          ];
          delete_unmanaged.enabled = false;
          sync_indexers = false;
        };
      };
    };
  };

  transmission = _: {
    services.transmission = {
      package = pkgs.transmission_4;
      home = "${appData.root}/transmission";
      group = dataRoot.group.name;
      credentialsFile = transmissionCredentials;
      downloadDirPermissions = "2770";
      settings = {
        download-dir = "${mediaRoot}/downloads/complete";
        incomplete-dir = "${mediaRoot}/downloads/incomplete";
        rpc-bind-address = "0.0.0.0";
        rpc-authentication-required = true;
        rpc-whitelist-enabled = false;
        rpc-host-whitelist-enabled = false;
        umask = "002";
      };
    };

    users.users.${config.services.transmission.user}.extraGroups = [
      appData.group.name
      dataRoot.group.name
    ];

    systemd.services = {
      transmission = {
        unitConfig.RequiresMountsFor = [ mediaRoot ];
        requires = [
          "transmission-setup.service"
          "transmission-credentials.service"
        ];
        after = [
          "transmission-setup.service"
          "transmission-credentials.service"
        ];
      };
      transmission-setup.unitConfig.RequiresMountsFor = [ mediaRoot ];
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

    networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
      config.services.transmission.settings.rpc-port
    ];
  };

  bazarr = _: {
    services.bazarr = {
      dataDir = "${appData.root}/bazarr";
      settings.general.ip = "0.0.0.0";
    };

    users.users.${config.services.bazarr.user}.extraGroups = [
      appData.group.name
      dataRoot.group.name
    ];

    systemd.services.bazarr = {
      unitConfig.RequiresMountsFor = [ "${dataRoot.path}/media" ];
      serviceConfig.UMask = lib.mkForce "0002";
    };

    networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
      config.services.bazarr.settings.general.port
    ];
  };

  configarr =
    _:
    let
      settings = {
        trashRevision = inputs."trash-guides".rev;
        sonarr = sonarr.configArr;
        radarr = radarr.configArr;
        prowlarr = prowlarr.configArr;
      };
      configarrFile = (pkgs.formats.yaml { tags = true; }).generate "configarr.yml" settings;
    in
    {
      services.configarr = {
        package = inputs.configarr.packages.${pkgs.stdenv.hostPlatform.system}.default;
        config = builtins.readFile configarrFile;
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
    };

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
