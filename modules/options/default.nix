{
  configurationName,
  config,
  lib,
  system,
  ...
}:

let
  inherit (lib) mkOption types;

  semanticScopes = import ./semantic-scopes.nix { inherit lib; };

  unknownScopePaths =
    path: overrides: resolved:
    lib.concatMap (
      name:
      let
        childPath = path ++ [ name ];
      in
      if !(builtins.hasAttr name resolved) then
        [ (lib.concatStringsSep "." childPath) ]
      else
        unknownScopePaths childPath overrides.${name} resolved.${name}
    ) (builtins.attrNames (builtins.removeAttrs overrides semanticScopes.scopeControlNames));

  leafChildDefaultPaths =
    path: overrides: resolved:
    let
      semanticChildren = builtins.removeAttrs resolved semanticScopes.resolvedScopeControlNames;
      childOverrides = builtins.removeAttrs overrides semanticScopes.scopeControlNames;
      nested = lib.concatMap (
        name:
        if builtins.hasAttr name resolved then
          leafChildDefaultPaths (path ++ [ name ]) childOverrides.${name} resolved.${name}
        else
          [ ]
      ) (builtins.attrNames childOverrides);
    in
    lib.optionals (overrides.children.enable != null && semanticChildren == { }) [
      (lib.concatStringsSep "." (
        path
        ++ [
          "children"
          "enable"
        ]
      ))
    ]
    ++ nested;

  unknownScopes = unknownScopePaths [ ] config.dotfiles.scopes config.dotfiles.resolvedScopes;
  leafChildDefaults = lib.concatMap (
    name:
    if builtins.hasAttr name config.dotfiles.resolvedScopes then
      leafChildDefaultPaths [ name ] config.dotfiles.scopes.${name} config.dotfiles.resolvedScopes.${name}
    else
      [ ]
  ) (builtins.attrNames config.dotfiles.scopes);
in
{
  options.dotfiles = {
    profile.name = mkOption {
      type = types.str;
      default = configurationName;
      description = "Configuration name for this host.";
    };

    secretsDir = mkOption {
      type = types.str;
      default = "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}/.secrets";
      description = "Absolute directory containing primary-user secrets.";
    };

    backups.secrets = {
      repository = mkOption {
        type = types.str;
        default = "rclone:dropbox:Archives/Backups/secrets/${config.dotfiles.profile.name}";
        description = "Encrypted repository holding this host's private secrets.";
      };

      credentialsDir = mkOption {
        type = types.str;
        default =
          if (lib.systems.elaborate system).isDarwin then
            "${config.dotfiles.users.primary.homeRoot}/${config.dotfiles.users.primary.name}/Library/Application Support/SecretsBackup"
          else if (lib.systems.elaborate system).isLinux then
            "/var/lib/backup-credentials"
          else
            throw "Unsupported host system: ${system}";
        description = "Directory for external backup bootstrap credentials.";
      };

      rcloneConfigFile = mkOption {
        type = types.str;
        default = "${config.dotfiles.backups.secrets.credentialsDir}/rclone.conf";
        description = "Runtime path for the backup transport configuration.";
      };

      passwordFile = mkOption {
        type = types.str;
        default = "${config.dotfiles.backups.secrets.credentialsDir}/secrets-restic-password";
        description = "Runtime path for the encrypted repository password.";
      };
    };

    backups.retention = {
      hourly = mkOption {
        type = types.ints.unsigned;
        default = 48;
        description = "Number of hourly recovery points to retain.";
      };

      daily = mkOption {
        type = types.ints.unsigned;
        default = 14;
        description = "Number of daily recovery points to retain.";
      };

      weekly = mkOption {
        type = types.ints.unsigned;
        default = 8;
        description = "Number of weekly recovery points to retain.";
      };

      monthly = mkOption {
        type = types.ints.unsigned;
        default = 12;
        description = "Number of monthly recovery points to retain.";
      };
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

    defaults.terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Default terminal executable used by desktop integrations.";
    };

    defaults.editor = mkOption {
      type = types.str;
      default = "nvim";
      description = "Default editor executable used by command-line tools.";
    };

    services.ollama.url = mkOption {
      type = types.str;
      default = "http://localhost:11434/v1";
      description = "OpenAI-compatible Ollama endpoint used by local tools.";
    };

    services.ntfy.url = mkOption {
      type = types.str;
      default = "http://nixos-server.home:2586";
      description = "Private ntfy endpoint used by infrastructure clients.";
    };

    scopes = mkOption {
      type = types.attrsOf semanticScopes.scopeOverrideType;
      default = { };
      description = "Host-specific enable overrides mirroring the semantic scope tree.";
    };

    resolvedScopes = mkOption {
      type = types.attrsOf semanticScopes.resolvedScopeType;
      default = { };
      internal = true;
      description = "Effective enable state for semantic scopes after inheritance and overrides.";
    };
  };

  config.assertions = [
    {
      assertion = unknownScopes == [ ];
      message = "Unknown semantic scope overrides: ${
        lib.concatStringsSep ", " (map (path: "dotfiles.scopes.${path}") unknownScopes)
      }";
    }
    {
      assertion = leafChildDefaults == [ ];
      message = "Semantic child defaults require child scopes: ${
        lib.concatStringsSep ", " (map (path: "dotfiles.scopes.${path}") leafChildDefaults)
      }";
    }
  ];
}
