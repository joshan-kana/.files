{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.homeAssistantStack;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionalAttrs
    optionals
    types
    ;

  dataRoot = cfg.dataRoot;
  secretsDir = "/root/secrets";
  resticRepository = "rclone:dropbox:Backups/nixos-home-assistant/restic";
  resticPasswordFile = "${secretsDir}/restic-password";
  rcloneConfigFile = "${secretsDir}/rclone.conf";
  backupPaths = [
    "${dataRoot}/home-assistant"
    "${dataRoot}/adguard"
    "${dataRoot}/matter-server"
    "${dataRoot}/n8n"
    "${dataRoot}/mosquitto"
    "${dataRoot}/zigbee2mqtt"
    "${dataRoot}/zwave-js-ui"
    "${dataRoot}/esphome"
    "${dataRoot}/openclaw"
  ];
in
{
  options.services.homeAssistantStack = {
    enable = mkEnableOption "Home Assistant and migrated add-on services";

    dataRoot = mkOption {
      type = types.str;
      default = "/var/lib";
      description = "Root directory for mutable Home Assistant and app data.";
    };

    snapshots.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable snapper snapshots for the mutable /var/lib subvolume.";
    };

    backups = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable encrypted restic backups for Home Assistant app data.";
      };
    };

    containers = {
      adguard.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run AdGuard Home as an OCI container.";
      };

      matter.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run the Home Assistant Matter Server as an OCI container.";
      };

      n8n.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run n8n as an OCI container.";
      };

      twingate.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Run the Twingate connector once its env file is provided.";
      };

      openclaw = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Run OpenClaw Assistant as an OCI container with fresh state.";
        };

        image = mkOption {
          type = types.str;
          default = "docker.io/17e0cc66/aarch64-addon-openclaw_assistant:0.5.77";
          description = ''
            OpenClaw container image to run. The default matches the image tag
            found in the HAOS backup; change this to the preferred upstream
            image/tag before enabling if a newer supported image exists.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      restic
      rclone
      snapper
    ];

    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    systemd.tmpfiles.rules = [
      "d ${dataRoot}/home-assistant 0750 root root - -"
      "d ${dataRoot}/adguard/work 0750 root root - -"
      "d ${dataRoot}/adguard/conf 0750 root root - -"
      "d ${dataRoot}/matter-server 0750 root root - -"
      "d ${dataRoot}/n8n 0750 root root - -"
      "d ${dataRoot}/mosquitto 0750 root root - -"
      "d ${dataRoot}/zigbee2mqtt 0750 root root - -"
      "d ${dataRoot}/zwave-js-ui 0750 root root - -"
      "d ${dataRoot}/esphome 0750 root root - -"
      "d ${dataRoot}/openclaw/config 0750 root root - -"
      "d ${dataRoot}/openclaw/data 0750 root root - -"
      "d ${secretsDir} 0700 root root - -"
    ];

    networking.firewall.allowedTCPPorts = [
      53 # AdGuard DNS
      8123 # Home Assistant
      3000 # AdGuard initial setup/admin
      5678 # n8n
      5580 # Matter Server
    ]
    ++ optionals cfg.containers.openclaw.enable [
      7681 # OpenClaw terminal
      18789 # OpenClaw gateway
    ];
    networking.firewall.allowedUDPPorts = [
      53 # AdGuard DNS
      5353 # mDNS for Home Assistant discovery
    ];

    virtualisation.oci-containers.containers = {
      home-assistant = {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        volumes = [
          "${dataRoot}/home-assistant:/config"
          "/run/dbus:/run/dbus:ro"
        ];
        extraOptions = [ "--network=host" ];
      };
    }
    // optionalAttrs cfg.containers.adguard.enable {
      adguard = {
        image = "adguard/adguardhome:latest";
        ports = [
          "53:53/tcp"
          "53:53/udp"
          "3000:3000/tcp"
        ];
        volumes = [
          "${dataRoot}/adguard/work:/opt/adguardhome/work"
          "${dataRoot}/adguard/conf:/opt/adguardhome/conf"
        ];
      };
    }
    // optionalAttrs cfg.containers.matter.enable {
      matter-server = {
        image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
        volumes = [ "${dataRoot}/matter-server:/data" ];
        extraOptions = [ "--network=host" ];
      };
    }
    // optionalAttrs cfg.containers.n8n.enable {
      n8n = {
        image = "docker.n8n.io/n8nio/n8n:latest";
        ports = [ "5678:5678/tcp" ];
        volumes = [ "${dataRoot}/n8n:/home/node/.n8n" ];
      };
    }
    // optionalAttrs cfg.containers.twingate.enable {
      twingate-connector = {
        image = "twingate/connector:latest";
        environmentFiles = [ "${secretsDir}/twingate-connector.env" ];
      };
    }
    // optionalAttrs cfg.containers.openclaw.enable {
      openclaw = {
        image = cfg.containers.openclaw.image;
        ports = [
          "7681:7681/tcp"
          "18789:18789/tcp"
        ];
        volumes = [
          "${dataRoot}/openclaw/config:/config"
          "${dataRoot}/openclaw/data:/data"
        ];
        environmentFiles = [ "${secretsDir}/openclaw.env" ];
      };
    };

    services.snapper = mkIf cfg.snapshots.enable {
      snapshotInterval = "15min";
      cleanupInterval = "1h";
      configs.var-lib = {
        SUBVOLUME = "/var/lib";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 48;
        TIMELINE_LIMIT_DAILY = 14;
        TIMELINE_LIMIT_WEEKLY = 8;
        TIMELINE_LIMIT_MONTHLY = 12;
      };
    };

    services.restic.backups.home-assistant = mkIf cfg.backups.enable {
      initialize = true;
      repository = resticRepository;
      passwordFile = resticPasswordFile;
      rcloneConfigFile = rcloneConfigFile;
      paths = backupPaths;
      exclude = [
        "${dataRoot}/home-assistant/home-assistant_v2.db-wal"
        "${dataRoot}/home-assistant/www/media/ha-bambulab"
      ];
      pruneOpts = [
        "--keep-hourly 48"
        "--keep-daily 14"
        "--keep-weekly 8"
        "--keep-monthly 12"
      ];
      timerConfig = {
        OnCalendar = "*:0/30";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
      checkOpts = [ "--read-data-subset=1G" ];
    };
  };
}
