{ inputs }:

let
  inherit (inputs.nixpkgs) lib;
  semantic = import ../lib/semantic-scopes.nix { inherit lib; };

  gitSettings = {
    init.defaultBranch = "main";
    user.name = "Portable Semantic Test";
  };

  systemEval = lib.evalModules {
    specialArgs = {
      inputs.marker = "portable-inputs";
      pkgs = { };
    };

    modules = [
      ({ lib, ... }: {
        options = {
          networking.hostName = lib.mkOption {
            type = lib.types.str;
            default = "darwin-shaped-host";
          };

          programs.git = {
            enable = lib.mkEnableOption "portable system Git";
            config = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          };

          home-manager.sharedModules = lib.mkOption {
            type = lib.types.listOf lib.types.deferredModule;
            default = [ ];
          };
        };
      })

      (semantic.systemModule "git" (
        { inputs, ... }:
        {
          programs.git.config = gitSettings;

          home =
            { darwinConfig, osConfig, ... }:
            {
              programs.git.settings = gitSettings;
              home.sessionVariables = {
                PORTABLE_DARWIN_HOST = darwinConfig.networking.hostName;
                PORTABLE_OS_HOST = osConfig.networking.hostName;
                PORTABLE_INPUTS = inputs.marker;
              };
            };
        }
      ))
    ];
  };

  homeEval = lib.evalModules {
    specialArgs = {
      inherit (systemEval) config;
      osConfig = systemEval.config;
      darwinConfig = systemEval.config;
      inputs.marker = "portable-inputs";
      modulesPath = "/darwin/modules";
      pkgs = { };
    };

    modules = [
      ({ lib, ... }: {
        options = {
          programs.git = {
            enable = lib.mkEnableOption "portable Home Manager Git";
            settings = lib.mkOption {
              type = lib.types.attrs;
              default = { };
            };
          };

          home.sessionVariables = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
          };
        };
      })
    ]
    ++ systemEval.config.home-manager.sharedModules;
  };
in
assert systemEval.config.programs.git.enable;
assert systemEval.config.programs.git.config == gitSettings;
assert homeEval.config.programs.git.enable;
assert homeEval.config.programs.git.settings == gitSettings;
assert homeEval.config.home.sessionVariables.PORTABLE_DARWIN_HOST == "darwin-shaped-host";
assert homeEval.config.home.sessionVariables.PORTABLE_OS_HOST == "darwin-shaped-host";
assert homeEval.config.home.sessionVariables.PORTABLE_INPUTS == "portable-inputs";
{
  systemGitEnabled = systemEval.config.programs.git.enable;
  homeGitEnabled = homeEval.config.programs.git.enable;
  sharedSettings = homeEval.config.programs.git.settings == gitSettings;
  darwinConfigForwarded = homeEval.config.home.sessionVariables.PORTABLE_DARWIN_HOST;
  osConfigForwarded = homeEval.config.home.sessionVariables.PORTABLE_OS_HOST;
}
