{ config, lib, ... }:

let
  inherit (lib) mkOption types;
  inherit (config.dotfiles.users) primary;
  primaryHome = "${primary.homeRoot}/${primary.name}";
in
{
  options.dotfiles.secrets = {
    requiredFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      apply = lib.unique;
      description = "Runtime secret files required by enabled configuration.";
    };

    mutableFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      apply = lib.unique;
      description = "Required secret files whose runtime owner may update their contents; provisioning restores them only when absent.";
    };

    doppler = {
      system = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Provision root-owned runtime secret files from a Doppler config.";
        };

        tokenFile = mkOption {
          type = types.str;
          default = "/var/lib/doppler-secrets/system.env";
          description = "Root-readable environment file containing DOPPLER_TOKEN for the system scope.";
        };

        targetDir = mkOption {
          type = types.str;
          default = "/var/lib/doppler-secrets/system";
          description = "Persistent directory receiving system-scope secret files.";
        };

        syncInterval = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional systemd interval for refreshing system secrets.";
        };
      };

      user = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Provision primary-user runtime secret files from a Doppler config.";
        };

        tokenFile = mkOption {
          type = types.str;
          default = "${primaryHome}/.config/doppler-secrets/user.env";
          description = "Primary-user environment file containing DOPPLER_TOKEN for the user scope.";
        };

        targetDir = mkOption {
          type = types.str;
          default = config.dotfiles.secretsDir;
          description = "Persistent directory receiving primary-user secret files.";
        };

        syncInterval = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional systemd user interval for refreshing user secrets.";
        };
      };
    };
  };
}
