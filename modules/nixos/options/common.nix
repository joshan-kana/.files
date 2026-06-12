{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.dotfiles = {
    profile.name = mkOption {
      type = types.str;
      description = "Flake profile name for this host.";
    };

    users.primary = {
      name = mkOption {
        type = types.str;
        default = "joshan";
        description = "Primary user account name.";
      };

      fullName = mkOption {
        type = types.str;
        default = "Joshan Kana";
        description = "Primary user's display name.";
      };

      email = mkOption {
        type = types.str;
        default = "joshankana@gmail.com";
        description = "Primary user's email address.";
      };

      homeRoot = mkOption {
        type = types.str;
        default = "/home";
        description = "Parent directory for normal user homes on this host.";
      };
    };

    paths.repoName = mkOption {
      type = types.str;
      default = ".files";
      description = "Repository directory name under the primary user's home.";
    };

    rebuild.flags = mkOption {
      type = types.str;
      default = "";
      description = "Additional flags passed to nixos-rebuild aliases.";
    };

    services.ollama.url = mkOption {
      type = types.str;
      default = "http://localhost:11434/v1";
      description = "OpenAI-compatible Ollama endpoint used by local tools.";
    };

    features = {
      cli.enable = mkEnableOption "shared CLI Home Manager configuration" // {
        default = true;
      };

      desktop.enable = mkEnableOption "Linux desktop configuration";
    };

    cli = {
      disabledPrograms = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Names of shared CLI programs to disable for this host.";
      };

      disabledAliases = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Names of shared shell aliases to disable for this host.";
      };
    };
  };
}
