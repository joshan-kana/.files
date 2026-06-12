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
  };
}
