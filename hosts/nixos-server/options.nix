{ lib, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.dotfiles.server = {
    appDataRoot = mkOption {
      type = types.str;
      default = "/var/lib/apps";
      description = "Root directory for server application data.";
    };

    secretsDir = mkOption {
      type = types.str;
      default = "/root/secrets";
      description = "Root directory for server secret files.";
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

    containers = {
      pullPolicy = mkOption {
        type = types.str;
        default = "always";
        description = "Default pull policy for server OCI containers.";
      };

      restartTrigger = mkOption {
        type = types.path;
        default = builtins.path {
          path = ../../flake.lock;
          name = "nixos-server-flake-lock";
        };
        description = "Path used to restart server containers when container inputs change.";
      };
    };
  };
}
