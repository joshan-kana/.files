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

    containers = {
      pullPolicy = mkOption {
        type = types.str;
        default = "always";
        description = "Default pull policy for server OCI containers.";
      };

      restartTrigger = mkOption {
        type = types.path;
        default = builtins.path {
          path = ../../../flake.lock;
          name = "nixos-server-flake-lock";
        };
        description = "Path used to restart server containers when container inputs change.";
      };
    };
  };
}
