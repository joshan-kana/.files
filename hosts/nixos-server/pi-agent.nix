{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.server.piAgent;
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;

  system = pkgs.stdenv.hostPlatform.system;
  llmAgentPackages = inputs.llm-agents.packages.${system} or { };

  hasAgentPackage = name: builtins.hasAttr name llmAgentPackages;
  selectedPackageNames = builtins.filter hasAgentPackage cfg.packageNames;
  missingPackageNames = builtins.filter (name: !(hasAgentPackage name)) cfg.packageNames;
  selectedPackages = builtins.map (name: builtins.getAttr name llmAgentPackages) selectedPackageNames;

  piAgent = pkgs.writeShellApplication {
    name = "pi-agent";
    runtimeInputs = selectedPackages;
    text = ''
      set -euo pipefail

      env_file=${lib.escapeShellArg cfg.environmentFile}
      worktree=${lib.escapeShellArg cfg.worktree}

      if [ -f "$env_file" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$env_file"
        set +a
      fi

      cd "$worktree"
      exec ${cfg.defaultCommand} "$@"
    '';
  };
in
{
  options.dotfiles.server.piAgent = {
    enable = lib.mkEnableOption "declarative Pi AI agent tooling" // {
      default = true;
    };

    packageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "codex" ];
      description = "Package names to install from the llm-agents flake.";
    };

    defaultCommand = lib.mkOption {
      type = lib.types.str;
      default = "codex";
      description = "Command run by the pi-agent wrapper.";
    };

    worktree = lib.mkOption {
      type = lib.types.str;
      default = "/home/${primaryUser}/.files";
      description = "Repository directory where pi-agent starts.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.str;
      default = "${serverCfg.secretsDir}/pi-agent.env";
      description = "Optional shell-style secret environment file loaded by pi-agent.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = missingPackageNames == [ ];
        message = "llm-agents does not provide these packages for ${system}: ${lib.concatStringsSep ", " missingPackageNames}";
      }
    ];

    environment.systemPackages = selectedPackages ++ [ piAgent ];

    systemd.tmpfiles.rules = [
      "d ${serverCfg.appDataRoot}/pi-agent 0750 ${primaryUser} users - -"
    ];
  };
}
