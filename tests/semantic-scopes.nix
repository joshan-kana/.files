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

  callableChild = lib.setFunctionArgs (args: {
    environment.variables.SEMANTIC_CALLABLE_PKGS = args.pkgs.stdenv.hostPlatform.system;
  }) { pkgs = false; };

  editedScope =
    semantic.editScope
      (_: {
        app = _: {
          environment.variables.SEMANTIC_EDIT_REPLACE = "shared";
          environment.systemPackages = [ inputs.nixpkgs.legacyPackages.${system}.coreutils ];
          systemd.services.semantic-edit-test = {
            after = [
              "remove.service"
              "keep.service"
            ];
            script = "echo shared";
          };
        };

        branch = _: {
          leaf = _: {
            environment.variables.SEMANTIC_EDIT_NESTED = "shared";
          };
        };
      })
      {
        app =
          {
            inherited,
            lib,
            pkgs,
            ...
          }:
          {
            environment.variables.SEMANTIC_EDIT_REPLACE = "host";
            environment.systemPackages = inherited.environment.systemPackages ++ [ pkgs.hello ];
            systemd.services.semantic-edit-test.after =
              builtins.filter (unit: unit != "remove.service") inherited.systemd.services.semantic-edit-test.after
              ++ [ "add.service" ];
            systemd.services.semantic-edit-test.script =
              lib.replaceStrings [ "shared" ] [ "host" ]
                inherited.systemd.services.semantic-edit-test.script;
          };

        branch = {
          leaf = _: {
            environment.variables.SEMANTIC_EDIT_NESTED = "host";
          };
        };
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
      (semantic.systemModule "edited" editedScope)
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

          callable = callableChild;

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

  standaloneHome = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    modules = [
      ../modules/options
      {
        dotfiles = {
          profile.name = "standalone-home";
          scopes.standalone = {
            childDefaults = {
              children.enable = false;
              explicit.enable = true;
            };
            hostDisabled.enable = false;
            disabled.enable = true;
          };
        };

        home = {
          username = "semantic";
          homeDirectory = "/home/semantic";
          stateVersion = "26.05";
        };
      }
      (semantic.homeModules {
        standalone = _: {
          imports = [
            (_: {
              environment.variables.SEMANTIC_HOME_IMPORTED_SYSTEM_LEAK = "bad";
            })
          ];
          environment.variables.SEMANTIC_HOME_SYSTEM_LEAK = "bad";

          home =
            { config, lib, ... }:
            {
              imports = [
                (_: {
                  home.sessionVariables.SEMANTIC_HOME_IMPORTED = "yes";
                })
              ];

              options.semanticHomeProbe = lib.mkOption {
                type = lib.types.str;
                default = "home-option-ok";
              };

              config.home.sessionVariables.SEMANTIC_HOME_CONFIG = config.semanticHomeProbe;
              home.sessionVariables.SEMANTIC_HOME_DIRECT = "yes";
            };

          nested = _: {
            environment.variables.SEMANTIC_HOME_NESTED_SYSTEM_LEAK = "bad";

            home = _: {
              home.sessionVariables.SEMANTIC_HOME_NESTED = "yes";
            };
          };

          childDefaults = _: {
            implicit = _: {
              home = _: {
                home.sessionVariables.SEMANTIC_HOME_CHILD_DEFAULT = "bad";
              };
            };

            explicit = _: {
              home = _: {
                home.sessionVariables.SEMANTIC_HOME_CHILD_EXPLICIT = "yes";
              };
            };
          };

          hostDisabled = _: {
            home = _: {
              home.sessionVariables.SEMANTIC_HOME_HOST_DISABLED = "bad";
            };
          };

          disabled = _: {
            enable = false;
            environment.variables.SEMANTIC_HOME_DISABLED_SYSTEM_LEAK = "bad";

            home = _: {
              home.sessionVariables.SEMANTIC_HOME_DISABLED = "yes";
            };
          };

          systemOnly = _: {
            environment.variables.SEMANTIC_HOME_SYSTEM_ONLY = "bad";
          };

          branchlessParent = _: {
            environment.variables.SEMANTIC_HOME_BRANCHLESS_SYSTEM_LEAK = "bad";

            nestedHome = _: {
              home = _: {
                home.sessionVariables.SEMANTIC_HOME_THROUGH_BRANCHLESS = "yes";
              };
            };
          };

          zsh = _: {
            environment.variables.SEMANTIC_HOME_ZSH_SYSTEM_LEAK = "bad";

            home = _: {
              programs.zsh.enableCompletion = true;
            };
          };
        };
      })
    ];
  };
  standaloneHomeCfg = standaloneHome.config;

  integratedOverrideHome = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    extraSpecialArgs.osConfig.dotfiles.scopes.integrated = {
      osDisabled.enable = false;
      osEnabled.enable = true;
    };
    modules = [
      ../modules/options
      {
        dotfiles = {
          profile.name = "integrated-home";
          scopes.integrated = {
            osDisabled.enable = true;
            osEnabled.enable = false;
          };
        };

        home = {
          username = "semantic";
          homeDirectory = "/home/semantic";
          stateVersion = "26.05";
        };
      }
      (semantic.homeModule "integrated" (_: {
        osDisabled = _: {
          home = _: {
            home.sessionVariables.SEMANTIC_HOME_OS_DISABLED = "bad";
          };
        };

        osEnabled = _: {
          home = _: {
            home.sessionVariables.SEMANTIC_HOME_OS_ENABLED = "yes";
          };
        };
      }))
    ];
  };
  integratedOverrideHomeCfg = integratedOverrideHome.config;

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
assert !builtins.isFunction callableChild;
assert lib.isFunction callableChild;
assert cfg.environment.variables.SEMANTIC_CALLABLE_PKGS == system;
assert cfg.environment.variables.SEMANTIC_EDIT_REPLACE == "host";
assert cfg.environment.variables.SEMANTIC_EDIT_NESTED == "host";
assert builtins.elem "hello" packageNames;
assert
  cfg.systemd.services.semantic-edit-test.after == [
    "keep.service"
    "add.service"
  ];
assert lib.hasInfix "echo host" cfg.systemd.services.semantic-edit-test.script;
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
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_DIRECT == "yes";
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_IMPORTED == "yes";
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_CONFIG == "home-option-ok";
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_NESTED == "yes";
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_THROUGH_BRANCHLESS == "yes";
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_DISABLED == "yes";
assert !(standaloneHomeCfg.home.sessionVariables ? SEMANTIC_HOME_CHILD_DEFAULT);
assert standaloneHomeCfg.home.sessionVariables.SEMANTIC_HOME_CHILD_EXPLICIT == "yes";
assert !(standaloneHomeCfg.home.sessionVariables ? SEMANTIC_HOME_HOST_DISABLED);
assert !standaloneHomeCfg.dotfiles.resolvedScopes.standalone.childDefaults.implicit.enable;
assert standaloneHomeCfg.dotfiles.resolvedScopes.standalone.childDefaults.explicit.enable;
assert !standaloneHomeCfg.dotfiles.resolvedScopes.standalone.hostDisabled.enable;
assert standaloneHomeCfg.dotfiles.resolvedScopes.standalone.disabled.enable;
assert standaloneHomeCfg.programs.zsh.enable;
assert standaloneHomeCfg.programs.zsh.enableCompletion;
assert !(integratedOverrideHomeCfg.home.sessionVariables ? SEMANTIC_HOME_OS_DISABLED);
assert integratedOverrideHomeCfg.home.sessionVariables.SEMANTIC_HOME_OS_ENABLED == "yes";
assert !integratedOverrideHomeCfg.dotfiles.resolvedScopes.integrated.osDisabled.enable;
assert integratedOverrideHomeCfg.dotfiles.resolvedScopes.integrated.osEnabled.enable;
true
