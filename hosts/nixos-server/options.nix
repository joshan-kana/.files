{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.dotfiles.server = {
    secretsDir = mkOption {
      type = types.str;
      default = "/root/secrets";
      description = "Root directory for server secret files.";
    };

    storage = {
      appData = {
        root = mkOption {
          type = types.str;
          default = "/var/lib/apps";
          description = "Root directory for server application data.";
        };

        group = {
          name = mkOption {
            type = types.str;
            default = "appdata-editors";
            description = "Group allowed to edit server application data.";
          };

          id = mkOption {
            type = types.ints.positive;
            default = 1500;
            description = "Fixed numeric ID for the application data editor group.";
          };
        };
      };

      dataRoot = {
        path = mkOption {
          type = types.str;
          default = "/srv/vault";
          description = "Mountpoint for bulk server data.";
        };

        poolName = mkOption {
          type = types.str;
          default = "vault";
          description = "Name of the ZFS pool used for bulk server storage.";
        };

        group.name = mkOption {
          type = types.str;
          default = "server-data";
          description = "Group allowed to collaborate on bulk server data.";
        };

        scrubInterval = mkOption {
          type = types.str;
          default = "weekly";
          description = "Systemd calendar interval for ZFS pool scrubs.";
        };
      };

      snapshots = {
        intervalMinutes = mkOption {
          type = types.ints.positive;
          default = 15;
          description = "Minutes between local filesystem snapshots.";
        };

        retention = {
          hourly = mkOption {
            type = types.ints.unsigned;
            default = 48;
            description = "Number of hourly local snapshots to retain.";
          };

          daily = mkOption {
            type = types.ints.unsigned;
            default = 14;
            description = "Number of daily local snapshots to retain.";
          };

          weekly = mkOption {
            type = types.ints.unsigned;
            default = 8;
            description = "Number of weekly local snapshots to retain.";
          };

          monthly = mkOption {
            type = types.ints.unsigned;
            default = 12;
            description = "Number of monthly local snapshots to retain.";
          };
        };
      };
    };

    lan = {
      interface = mkOption {
        type = types.str;
        default = "end0";
        description = "Primary wired LAN interface for the server.";
      };

      subnet = mkOption {
        type = types.str;
        default = "192.168.1.0/24";
        description = "Primary home LAN subnet.";
      };

      gateway = mkOption {
        type = types.str;
        default = "192.168.1.1";
        description = "Default IPv4 gateway for the home LAN.";
      };

      serverIp = mkOption {
        type = types.str;
        default = "192.168.1.3";
        description = "Primary LAN IPv4 address for the NixOS server.";
      };

      dns = {
        serviceIp = mkOption {
          type = types.str;
          default = "192.168.1.2";
          description = "Dedicated LAN IPv4 address for the local DNS service.";
        };

        fallbackServers = mkOption {
          type = types.listOf types.str;
          default = [
            "192.168.1.1"
            "1.1.1.1"
          ];
          description = "Fallback DNS servers for the NixOS host when the local DNS service is unavailable.";
        };

        macvlanHostShimIp = mkOption {
          type = types.str;
          default = "192.168.1.5";
          description = "Host-side macvlan shim address used while the LAN DNS service runs in Docker.";
        };
      };
    };
  };
}
