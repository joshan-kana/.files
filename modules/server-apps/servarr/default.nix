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
  streamystatsStateDir = "${appData.root}/streamystats";
  streamystatsCredentialsFile = "${server.secretsDir}/streamystats.env";
  streamystatsPort = 3013;
in
{
  streamystats = _: {
    virtualisation.oci-containers.containers.streamystats = {
      image = "ghcr.io/fredrikburmester/streamystats-aio:latest";
      volumes = [ "${streamystatsStateDir}:/var/lib/postgresql/data" ];
      ports = [ "${server.lan.serverIp}:${toString streamystatsPort}:3000" ];
      environment = {
        POSTGRES_HOST_AUTH_METHOD = "scram-sha-256";
        POSTGRES_INITDB_ARGS = "--auth-host=scram-sha-256";
      };
      environmentFiles = [ streamystatsCredentialsFile ];
      extraOptions = [ "--stop-timeout=60" ];
    };

    systemd = {
      tmpfiles.rules = [
        "d ${streamystatsStateDir} 0700 root root - -"
      ];

      services = {
        streamystats-credentials = {
          description = "Initialize Streamystats credentials";
          serviceConfig.Type = "oneshot";
          script = ''
            set -eu
            umask 077
            install -d -m 0700 '${server.secretsDir}'
            if [ ! -e '${streamystatsCredentialsFile}' ]; then
              db_password="$(${pkgs.openssl}/bin/openssl rand -hex 24)"
              session_secret="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
              actions_key="$(${pkgs.openssl}/bin/openssl rand -base64 32 | tr -d '\n')"
              file="$(mktemp '${server.secretsDir}/.streamystats.XXXXXXXX')"
              trap 'rm -f "$file"' EXIT
              printf 'POSTGRES_PASSWORD=%s\nSESSION_SECRET=%s\nNEXT_SERVER_ACTIONS_ENCRYPTION_KEY=%s\nDATABASE_URL=postgresql://postgres:%s@localhost:5432/streamystats\n' \
                "$db_password" "$session_secret" "$actions_key" "$db_password" > "$file"
              mv -n "$file" '${streamystatsCredentialsFile}'
            fi
          '';
        };

        docker-streamystats = {
          requires = [ "streamystats-credentials.service" ];
          after = [ "streamystats-credentials.service" ];
          unitConfig.RequiresMountsFor = [ streamystatsStateDir ];
        };
      };
    };
  };

  seerr = _: {
    services.seerr = {
      enable = true;
      stateRevision = 1;
      configDir = "${appData.root}/seerr";
    };

    users = {
      groups.seerr = { };
      users.seerr = {
        isSystemUser = true;
        group = "seerr";
        extraGroups = [ appData.group.name ];
      };
    };

    systemd = {
      services.seerr.serviceConfig = {
        DynamicUser = lib.mkForce false;
        StateDirectory = lib.mkForce "";
        User = "seerr";
        Group = "seerr";
        ReadWritePaths = [ config.services.seerr.configDir ];
        BindPaths = [
          "${config.services.seerr.configDir}/next-cache:${config.services.seerr.package}/share/.next/cache"
        ];
      };
      tmpfiles.rules = [
        "d ${config.services.seerr.configDir} 0700 seerr seerr - -"
        "d ${config.services.seerr.configDir}/next-cache 0700 seerr seerr - -"
      ];
    };

    networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
      config.services.seerr.port
    ];
  };

  sonarr = _: {
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

    services.configarr.settings.sonarr = {
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
          {
            trash_ids = [ "69aa1e159f97d860440b04cd6d590c4f" ]; # Not English
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = -2000;
              }
            ];
          }
          {
            trash_ids = [ "ae575f95ab639ba5d15f663bf019e3e8" ]; # Not Original
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = -250;
              }
            ];
          }
          {
            trash_ids = [ "418f50b10f1907201b6cfdf881f467b7" ]; # Anime Dual Audio
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 2250;
              }
            ];
          }
          {
            trash_ids = [ "1bef6c151fa35093015b0bfef18279e5" ]; # 2160p
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 100;
              }
            ];
          }
        ];
        quality_profiles = [
          {
            name = "Ultra-HD";
            upgrade = {
              allowed = true;
              until_quality = "HD and UHD";
              until_score = 10000;
            };
            min_format_score = -250;
            qualities = [
              {
                name = "HD and UHD";
                qualities = [
                  "Bluray-2160p"
                  "WEBDL-2160p"
                  "WEBRip-2160p"
                  "HDTV-2160p"
                  "Bluray-1080p"
                  "WEBDL-1080p"
                  "WEBRip-1080p"
                  "HDTV-1080p"
                ];
              }
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

  radarr = _: {
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

    services.configarr.settings.radarr = {
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
          {
            trash_ids = [ "0dc8aec3bd1c47cd6c40c46ecd27e846" ]; # Not English
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = -2000;
              }
            ];
          }
          {
            trash_ids = [ "d6e9318c875905d6cfb5bee961afcea9" ]; # Not Original
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = -250;
              }
            ];
          }
          {
            trash_ids = [ "4a3b087eea2ce012fcc1ce319259a3be" ]; # Anime Dual Audio
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 2250;
              }
            ];
          }
          {
            trash_ids = [ "fb392fb0d61a010ae38e49ceaa24a1ef" ]; # 2160p
            assign_scores_to = [
              {
                name = "Ultra-HD";
                score = 100;
              }
            ];
          }
        ];
        quality_profiles = [
          {
            name = "Ultra-HD";
            language = "Any";
            upgrade = {
              allowed = true;
              until_quality = "HD and UHD";
              until_score = 10000;
            };
            min_format_score = -250;
            qualities = [
              {
                name = "HD and UHD";
                qualities = [
                  "Bluray-2160p"
                  "WEBDL-2160p"
                  "WEBRip-2160p"
                  "HDTV-2160p"
                  "Bluray-1080p"
                  "WEBDL-1080p"
                  "WEBRip-1080p"
                  "HDTV-1080p"
                ];
              }
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

  prowlarr = _: {
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

    services.configarr.settings.prowlarr = {
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

  configarr = _: {
    services.configarr.settings.trashRevision = inputs."trash-guides".rev;

    services.configarr = {
      package = pkgs.configarr;
      dataDir = "${appData.root}/configarr";
      environmentFile = "${server.secretsDir}/configarr.env";
    };

    users.users.${config.services.configarr.user}.extraGroups = [ appData.group.name ];

    # Keep the daily timer, but also apply changed settings when NixOS switches.
    systemd.services.configarr-apply = {
      description = "Apply Configarr settings on deployment";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        (pkgs.writeText "configarr-applied-settings.yml" config.services.configarr.config)
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.systemd}/bin/systemctl start --wait configarr.service";
      };
    };

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
