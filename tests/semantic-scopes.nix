{ inputs, system }:

let
  inherit (inputs.nixpkgs) lib;
  semantic = import ../lib/semantic-scopes.nix { inherit lib; };

  gitSettings = {
    init.defaultBranch = "main";
    user.name = "Semantic Test";
    core.editor = "nvim";
  };

  sharedZshConfig = _: {
    programs.zsh.enableCompletion = true;
  };

  evaluated = inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs.inputs = {
      marker = "from-inputs";
    };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      ../modules/options
      ({ lib, pkgs, ... }: {
        networking.hostName = "semantic-test";
        system.stateVersion = "26.05";
        users.users.semantic.isNormalUser = true;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.semantic.home.stateVersion = "26.05";

        dotfiles = {
          profile.name = "semantic-test";
          users.primary.name = "semantic";
          scopes.semantic = {
            externalDisabled.enable = false;
            sourceDisabled.enable = true;
            parentOverride = {
              enable = false;
              child.enable = true;
            };
            childDefaults = {
              children.enable = false;
              explicitEnabled.enable = true;
            };
            nested.branch.children.enable = false;
          };
        };

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

          zsh = args: {
            programs.zsh = (sharedZshConfig args).programs.zsh;

            home = args: {
              programs.zsh = (sharedZshConfig args).programs.zsh;
            };
          };

          externalDisabled = _: {
            environment.variables.SEMANTIC_EXTERNAL_DISABLED = "bad";
            home = _: {
              home.sessionVariables.SEMANTIC_EXTERNAL_DISABLED = "bad";
            };
          };

          sourceDisabled = _: {
            enable = false;
            environment.variables.SEMANTIC_SOURCE_REENABLED = "yes";
            home = _: {
              home.sessionVariables.SEMANTIC_SOURCE_REENABLED = "yes";
            };
          };

          parentOverride = _: {
            child = _: {
              environment.variables.SEMANTIC_PARENT_OVERRIDE = "bad";
              home = _: {
                home.sessionVariables.SEMANTIC_PARENT_OVERRIDE = "bad";
              };
            };
          };

          childDefaults = _: {
            implicit = _: {
              environment.variables.SEMANTIC_CHILD_DEFAULT = "bad";
            };

            explicitEnabled = _: {
              environment.variables.SEMANTIC_CHILD_EXPLICIT = "yes";
            };

            sourceEnabled = _: {
              enable = true;
              environment.variables.SEMANTIC_CHILD_SOURCE_ENABLED = "yes";
            };

            sourceDisabled = _: {
              enable = false;
              environment.variables.SEMANTIC_CHILD_SOURCE_DISABLED = "bad";
            };
          };

          nested = _: {
            branch = _: {
              leaf = _: {
                environment.variables.SEMANTIC_NESTED_CHILD_DEFAULT = "bad";
              };
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

  scopeValidationAssertion =
    evaluation:
    lib.findFirst (
      assertion: lib.hasPrefix "Unknown semantic scope overrides:" assertion.message
    ) null evaluation.config.assertions;
  invalidNestedOverride = evaluated.extendModules {
    modules = [
      {
        dotfiles.scopes.semantic.parentOverride.stale.enable = false;
      }
    ];
  };
  invalidTopLevelOverride = evaluated.extendModules {
    modules = [
      {
        dotfiles.scopes.stale.enable = false;
      }
    ];
  };
  nestedValidation = scopeValidationAssertion invalidNestedOverride;
  topLevelValidation = scopeValidationAssertion invalidTopLevelOverride;
  invalidLeafChildDefault = evaluated.extendModules {
    modules = [
      {
        dotfiles.scopes.semantic.childDefaults.implicit.children.enable = false;
      }
    ];
  };
  leafChildDefaultValidation = lib.findFirst (
    assertion: lib.hasPrefix "Semantic child defaults require child scopes:" assertion.message
  ) null invalidLeafChildDefault.config.assertions;
  reservedChildEvaluation = lib.evalModules {
    modules = [
      (semantic.systemModule "reserved" (_: {
        children = _: { };
      }))
    ];
  };
  reservedChildResult = builtins.tryEval (builtins.deepSeq reservedChildEvaluation.config true);

  cfg = evaluated.config;
  hm = cfg.home-manager.users.semantic;
  packageNames = map lib.getName cfg.environment.systemPackages;
in
assert nestedValidation != null;
assert !nestedValidation.assertion;
assert lib.hasInfix "dotfiles.scopes.semantic.parentOverride.stale" nestedValidation.message;
assert topLevelValidation != null;
assert !topLevelValidation.assertion;
assert lib.hasInfix "dotfiles.scopes.stale" topLevelValidation.message;
assert !reservedChildResult.success;
assert leafChildDefaultValidation != null;
assert !leafChildDefaultValidation.assertion;
assert lib.hasInfix "dotfiles.scopes.semantic.childDefaults.implicit.children.enable"
  leafChildDefaultValidation.message;
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
assert cfg.programs.zsh.enable;
assert hm.programs.zsh.enable;
assert cfg.programs.zsh.enableCompletion;
assert hm.programs.zsh.enableCompletion;
assert !(cfg.environment.variables ? SEMANTIC_EXTERNAL_DISABLED);
assert !(hm.home.sessionVariables ? SEMANTIC_EXTERNAL_DISABLED);
assert cfg.environment.variables.SEMANTIC_SOURCE_REENABLED == "yes";
assert hm.home.sessionVariables.SEMANTIC_SOURCE_REENABLED == "yes";
assert !(cfg.environment.variables ? SEMANTIC_PARENT_OVERRIDE);
assert !(hm.home.sessionVariables ? SEMANTIC_PARENT_OVERRIDE);
assert !(cfg.environment.variables ? SEMANTIC_CHILD_DEFAULT);
assert cfg.environment.variables.SEMANTIC_CHILD_EXPLICIT == "yes";
assert cfg.environment.variables.SEMANTIC_CHILD_SOURCE_ENABLED == "yes";
assert !(cfg.environment.variables ? SEMANTIC_CHILD_SOURCE_DISABLED);
assert !(cfg.environment.variables ? SEMANTIC_NESTED_CHILD_DEFAULT);
assert !cfg.dotfiles.resolvedScopes.semantic.childDefaults.implicit.enable;
assert cfg.dotfiles.resolvedScopes.semantic.childDefaults.explicitEnabled.enable;
assert cfg.dotfiles.resolvedScopes.semantic.childDefaults.sourceEnabled.enable;
assert !cfg.dotfiles.resolvedScopes.semantic.childDefaults.sourceDisabled.enable;
assert cfg.dotfiles.resolvedScopes.semantic.nested.branch.enable;
assert !cfg.dotfiles.resolvedScopes.semantic.nested.branch.leaf.enable;
assert !cfg.dotfiles.resolvedScopes.semantic.externalDisabled.enable;
assert cfg.dotfiles.resolvedScopes.semantic.sourceDisabled.enable;
assert !cfg.dotfiles.resolvedScopes.semantic.parentOverride.enable;
assert !cfg.dotfiles.resolvedScopes.semantic.parentOverride.child.enable;
assert builtins.elem "hello" packageNames;
true
