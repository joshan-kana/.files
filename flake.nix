{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: a collection of packages for the Nix package manager
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Stable Nixpkgs for server hosts where predictable updates matter more.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # NixOS hardware profiles, including Raspberry Pi 4 defaults.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Stylix: systemwide theming and typography for NixOS
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix-stable = {
      url = "github:nix-community/stylix/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Home Manager: a tool for managing dotfiles using Nix
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    # Spicetify-nix: a nix flake for the spicetify-cli (theming Spotify)
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma-manager: a nix flake for managing KDE Plasma
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Zen Browser: community flake that wraps upstream browser binaries.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      home-manager-stable,
      stylix,
      stylix-stable,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      semantic = import ./lib/semantic-scopes.nix { inherit lib; };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems f;

      pkgsFor = system: import nixpkgs { inherit system; };

      repoToolExcludedDirs = [
        ".direnv/"
        "patches/"
        "docs/infrastructure-docs/"
      ];

      treefmtExcludes = map (dir: "${dir}**") repoToolExcludedDirs;
      preCommitExcludes = map (dir: "^${lib.escapeRegex dir}") repoToolExcludedDirs;
      gitPathspecExcludeArgs = lib.concatMapStringsSep " " (
        dir: lib.escapeShellArg ":(exclude)${dir}**"
      ) repoToolExcludedDirs;

      treefmtFor =
        system: includeChecks:
        let
          pkgs = pkgsFor system;
          markdownOptions = [
            "--disable"
            "MD013,MD057"
          ];
          typosConfig = pkgs.writeText "typos.toml" ''
            [default.extend-words]
            hass = "hass"
          '';
        in
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";

          programs = {
            deadnix.enable = true;
            nixfmt.enable = true;
            ruff-check.enable = true;
            ruff-format = {
              enable = true;
              lineLength = 140;
            };
            rumdl-check.enable = true;
            rumdl-format.enable = true;
            statix = {
              enable = true;
              disabled-lints = [ "repeated_keys" ];
            };
            typos = {
              enable = true;
              configFile = toString typosConfig;
              includes = [ "*.md" ];
            };
          }
          // lib.optionalAttrs includeChecks {
            shellcheck = {
              enable = true;
              includes = [
                ".envrc"
                "scripts/**"
                "tests/**"
              ];
              excludes = [
                "*.md"
                "*.nix"
                "*.py"
              ];
              severity = "warning";
            };
            yamllint = {
              enable = true;
              settings = {
                extends = "default";
                rules = {
                  comments.min-spaces-from-content = 1;
                  document-start = "disable";
                  line-length = "disable";
                  truthy.check-keys = false;
                };
              };
            };
          };

          settings = {
            excludes = treefmtExcludes;

            formatter = {
              deadnix.priority = 1;
              statix.priority = 2;
              nixfmt.priority = 3;

              ruff-check = {
                options = [
                  "--isolated"
                  "--select"
                  "E4,E7,E9,F,I"
                ];
                priority = 1;
              };
              ruff-format.priority = 2;

              rumdl-format = {
                options = markdownOptions;
                priority = 1;
              };
              rumdl-check = {
                options = markdownOptions;
                priority = 2;
              };
              typos.priority = 3;
            }
            // lib.optionalAttrs includeChecks {
              actionlint = {
                command = lib.getExe pkgs.actionlint;
                includes = [
                  ".github/workflows/*.yml"
                  ".github/workflows/*.yaml"
                ];
              };
            };
          };
        };

      preCommitFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        pre-commit-hooks.lib.${system}.run {
          src = self;
          hooks = {
            repo-quality = {
              enable = true;
              name = "Repository formatting and linting";
              entry = "${lib.getExe pkgs.nix} build --no-link .#checks.${system}.repo-quality";
              files = "\\.(nix|md|py|sh|ya?ml)$|^\\.envrc$|^scripts/";
              excludes = preCommitExcludes;
              pass_filenames = false;
            };

            staged-whitespace = {
              enable = true;
              name = "Staged whitespace";
              entry = "${lib.getExe pkgs.git} diff --check --cached -- . ${gitPathspecExcludeArgs}";
              pass_filenames = false;
              always_run = true;
            };
          };
        };

      nixosHost =
        {
          system,
          hostModule,
          nixpkgsInput ? nixpkgs,
          homeManagerInput ? home-manager,
          stylixInput ? stylix,
          extraModules ? [ ],
        }:
        let
          hostFile =
            if builtins.pathExists (hostModule + "/default.nix") then
              hostModule + "/default.nix"
            else
              hostModule;
          hostScope = import hostFile;
          hostScopeWithFile = lib.setFunctionArgs (args: (hostScope args) // { _file = toString hostFile; }) (
            lib.functionArgs hostScope
          );
        in
        nixpkgsInput.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs;
            moduleRegistry = import ./modules;
          };
          modules = [
            ./modules/options
            stylixInput.nixosModules.stylix
            homeManagerInput.nixosModules.home-manager
            (semantic.rootModule hostScopeWithFile)
          ]
          ++ extraModules;
        };
    in
    {
      formatter = forAllSystems (system: (treefmtFor system false).config.build.wrapper);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system false;
          preCommit = preCommitFor system;
          repoOptionsFzf = pkgs.writeShellApplication {
            name = "nf";
            runtimeInputs = with pkgs; [
              fzf
              coreutils
              git
              jq
              nix
            ];
            text = ''
              repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              NIX_OPTIONS_FZF_CMD_NAME="''${0##*/}" exec "$repo/scripts/nix-options-fzf" "$@"
            '';
          };

          formatRepo = pkgs.writeShellScriptBin "fmt" ''
            exec ${lib.getExe treefmt.config.build.wrapper} "$@"
          '';
          checkRepo = pkgs.writeShellScriptBin "chk" ''
            exec ${lib.getExe pkgs.nix} flake check "$@"
          '';

          commonTools =
            with pkgs;
            [
              nixfmt
              nixd
              nil
              statix
              deadnix
              jq
              skopeo
            ]
            ++ [
              checkRepo
              formatRepo
              repoOptionsFzf
              treefmt.config.build.wrapper
            ];

          vscodePkg = pkgs.vscodium or (pkgs.vscode or null);
        in
        {
          default = pkgs.mkShell {
            packages = commonTools;
            inherit (preCommit) shellHook;
          };

          vscode = pkgs.mkShell {
            packages = commonTools ++ lib.optionals (vscodePkg != null) [ vscodePkg ];
            inherit (preCommit) shellHook;
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system true;
          semanticTest = import ./tests/semantic-scopes.nix { inherit inputs system; };
          semanticPortabilityTest = import ./tests/semantic-system-portability.nix { inherit inputs; };
        in
        {
          nixos-eval = builtins.deepSeq (builtins.mapAttrs (
            _: host: host.config.system.build.bootStage2.drvPath
          ) self.nixosConfigurations) pkgs.emptyFile;
          repo-quality = treefmt.config.build.check self;
          semantic-system-portability = pkgs.writeText "semantic-system-portability-test.json" (
            builtins.toJSON semanticPortabilityTest
          );
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          semantic-scopes = pkgs.writeText "semantic-scopes-test.json" (builtins.toJSON semanticTest);
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system false;
          plasmaRc2nix = lib.attrByPath [ system "rc2nix" ] null inputs.plasma-manager.packages;

          updatePlasma =
            if plasmaRc2nix == null then
              null
            else
              pkgs.writeShellApplication {
                name = "update-plasma";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.git
                  treefmt.config.build.wrapper
                  plasmaRc2nix
                ];
                text = ''
                  repo="$(git rev-parse --show-toplevel)"
                  target="$repo/modules/desktop/plasma/generated.nix"
                  tmpdir="$(mktemp -d "$repo/modules/desktop/plasma/.generated.XXXXXX")"
                  trap 'rm -rf -- "$tmpdir"' EXIT

                  rc2nix > "$tmpdir/generated.nix"
                  treefmt "$tmpdir/generated.nix"
                  mv -- "$tmpdir/generated.nix" "$target"
                '';
              };

          vscodePkg = pkgs.vscodium or (pkgs.vscode or null);
        in
        lib.optionalAttrs (updatePlasma != null) {
          update-plasma = {
            type = "app";
            program = lib.getExe updatePlasma;
            meta.description = "Regenerate Plasma Manager configuration with pinned rc2nix and treefmt";
          };
        }
        // lib.optionalAttrs (vscodePkg != null) {
          code = {
            type = "app";
            program = lib.getExe vscodePkg;
          };
        }
      );
      nixosConfigurations = {
        nixos = nixosHost {
          system = "x86_64-linux";
          hostModule = ./hosts/nixos;
        };

        nixos-arm-parallels = nixosHost {
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-arm-parallels;
        };

        nixos-orbstack = nixosHost {
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-orbstack;
        };

        nixos-server = nixosHost {
          nixpkgsInput = nixpkgs-stable;
          homeManagerInput = home-manager-stable;
          stylixInput = stylix-stable;
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-server;
        };
      };
    };
}
