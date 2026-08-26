{ config, lib, ... }:

let
  inherit (lib) mkOption types;

  scopeOverrideType =
    (types.submodule (_: {
      freeformType = types.attrsOf scopeOverrideType;

      options.enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Optional enable override for this semantic scope.";
      };
    }))
    // {
      description = "semantic scope override";
    };

  resolvedScopeType =
    (types.submodule (_: {
      freeformType = types.attrsOf resolvedScopeType;

      options.enable = mkOption {
        type = types.bool;
        internal = true;
      };
    }))
    // {
      description = "resolved semantic scope state";
    };
in
{
  options.dotfiles = {
    profile.name = mkOption {
      type = types.str;
      description = "Flake profile name for this host.";
    };

    secretsDir = mkOption {
      type = types.str;
      default = "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}/.secrets";
      description = "Absolute directory containing primary-user secrets.";
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

    paths = {
      repoName = mkOption {
        type = types.str;
        default = ".files";
        description = "Repository directory name under the primary user's home.";
      };

      repoPath = mkOption {
        type = types.str;
        default = "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}/${config.dotfiles.paths.repoName}";
        description = "Absolute path to the repository.";
      };
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

    scopes = mkOption {
      type = types.attrsOf scopeOverrideType;
      default = { };
      description = "Host-specific enable overrides mirroring the semantic scope tree.";
    };

    resolvedScopes = mkOption {
      type = types.attrsOf resolvedScopeType;
      default = { };
      internal = true;
      description = "Effective enable state for semantic scopes after inheritance and overrides.";
    };
  };
}
