{ inputs, system }:

let
  inherit (inputs.nixpkgs) lib;
  semantic = import ../lib/semantic-scopes.nix { inherit lib; };

  gitSettings = {
    init.defaultBranch = "main";
    user.name = "Semantic Test";
    core.editor = "nvim";
  };

  evaluated = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs.inputs = {
      marker = "from-inputs";
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      ({ lib, pkgs, ... }: {
        networking.hostName = "semantic-test";
        system.stateVersion = "26.05";
        users.users.semantic.isNormalUser = true;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.semantic.home.stateVersion = "26.05";

        environment.variables.SEMANTIC_FORCE = lib.mkForce "outside";
        environment.systemPackages = [ pkgs.coreutils ];
      })
      (semantic.systemModule "semantic" (
        {
          config,
          inputs,
          lib,
          modulesPath,
          pkgs,
          ...
        }:
        {
          imports = [
            (_: {
              environment.variables.SEMANTIC_IMPORTED = "yes";
            })
          ];

          options.semanticProbe = lib.mkOption {
            type = lib.types.str;
            default = "option-ok";
          };

          config.environment.variables = {
            SEMANTIC_CONFIG = "yes";
            SEMANTIC_OPTION = config.semanticProbe;
          };

          environment.variables.SEMANTIC_FORCE = lib.mkDefault "inside";
          environment.systemPackages = lib.mkAfter [ pkgs.hello ];

          args = _: {
            environment.variables = {
              SEMANTIC_INPUTS = inputs.marker;
              SEMANTIC_MODULES_PATH = modulesPath;
              SEMANTIC_PKGS = pkgs.stdenv.hostPlatform.system;
            };
          };

          git = _: {
            programs.git.config = gitSettings;

            home =
              { osConfig, pkgs, ... }:
              {
                programs.git.settings = gitSettings;
                home.packages = [ pkgs.hello ];
                home.sessionVariables.SEMANTIC_OS_HOST = osConfig.networking.hostName;
              };
          };

          disabled = _: {
            enable = false;
            environment.variables.SEMANTIC_DISABLED = "bad";
          };

          parentDisabled = _: {
            enable = false;
            child = _: {
              environment.variables.SEMANTIC_CASCADE = "bad";
            };
          };
        }
      ))
    ];
  };

  cfg = evaluated.config;
  hm = cfg.home-manager.users.semantic;
  packageNames = map lib.getName cfg.environment.systemPackages;
in
assert cfg.programs.git.enable;
assert hm.programs.git.enable;
assert hm.programs.git.settings == gitSettings;
assert cfg.environment.variables.SEMANTIC_IMPORTED == "yes";
assert cfg.environment.variables.SEMANTIC_CONFIG == "yes";
assert cfg.environment.variables.SEMANTIC_OPTION == "option-ok";
assert cfg.environment.variables.SEMANTIC_FORCE == "outside";
assert cfg.environment.variables.SEMANTIC_INPUTS == "from-inputs";
assert cfg.environment.variables.SEMANTIC_PKGS == system;
assert cfg.environment.variables.SEMANTIC_MODULES_PATH != "";
assert hm.home.sessionVariables.SEMANTIC_OS_HOST == "semantic-test";
assert !(cfg.environment.variables ? SEMANTIC_DISABLED);
assert !(cfg.environment.variables ? SEMANTIC_CASCADE);
assert builtins.elem "hello" packageNames;
{
  gitNixosEnabled = cfg.programs.git.enable;
  gitHomeEnabled = hm.programs.git.enable;
  gitSettingsShared = hm.programs.git.settings == gitSettings;
  importedModule = cfg.environment.variables.SEMANTIC_IMPORTED;
  optionValue = cfg.environment.variables.SEMANTIC_OPTION;
  forcedValue = cfg.environment.variables.SEMANTIC_FORCE;
  childInputs = cfg.environment.variables.SEMANTIC_INPUTS;
  childSystem = cfg.environment.variables.SEMANTIC_PKGS;
  homeOsHost = hm.home.sessionVariables.SEMANTIC_OS_HOST;
  disabledAbsent = !(cfg.environment.variables ? SEMANTIC_DISABLED);
  cascadeAbsent = !(cfg.environment.variables ? SEMANTIC_CASCADE);
}
