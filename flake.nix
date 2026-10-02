{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: a collection of packages for the Nix package manager
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Stable Nixpkgs for server hosts where predictable updates matter more.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Hermes Agent: native NixOS service/module.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt AI agent packages.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # First-party OpenClaw NixOS service module.
    nix-openclaw.url = "github:openclaw/nix-openclaw";

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

    determinate-nix.url = "https://flakehub.com/f/DeterminateSystems/nix-src/3";

    mautrix-packages.url = "github:Moraxyc/nur-packages";

    computer = {
      url = "file+https://pypi.org/pypi/cptr/json";
      flake = false;
    };

    openai-tunnel = {
      url = "file+https://github.com/openai/tunnel-client/releases/latest/download/SHA256SUMS.txt";
      flake = false;
    };

    agentgateway-linux-amd64 = {
      url = "file+https://github.com/agentgateway/agentgateway/releases/latest/download/agentgateway-linux-amd64";
      flake = false;
    };

    agentgateway-linux-arm64 = {
      url = "file+https://github.com/agentgateway/agentgateway/releases/latest/download/agentgateway-linux-arm64";
      flake = false;
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
      semanticScopeOptions = import ./modules/options/semantic-scopes.nix { inherit lib; };

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
        system:
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
            };
            statix = {
              enable = true;
              disabled-lints = [ "repeated_keys" ];
            };
            typos = {
              enable = true;
              configFile = toString typosConfig;
              includes = [ "*.md" ];
            };
            yamllint = {
              enable = true;
              settings = {
                extends = "default";
                rules = {
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
              statix.priority = 1;
              nixfmt.priority = 2;

              ruff-check.options = [
                "--isolated"
                "--select"
                "E4,E7,E9,F,I"
              ];
              ruff-format.priority = 1;

              rumdl-format.options = markdownOptions;
              rumdl-check = {
                options = markdownOptions;
                priority = 2;
              };
              typos.priority = 1;
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
              entry = "nix build --no-link .#checks.${system}.repo-quality";
              files = "\\.(lock|md|nix|py|sh|ya?ml)$|^\\.envrc$|^scripts/";
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
        configurationName:
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
            inherit configurationName inputs;
            inherit (semantic)
              editScope
              extendScope
              ;
            moduleRegistry = import ./modules;
          };
          modules = [
            ./modules/options
            stylixInput.nixosModules.stylix
            homeManagerInput.nixosModules.home-manager
            ./overlays/comin.nix
            ./overlays/libreoffice.nix
            ./overlays/nixos-options-doc.nix
            (semantic.rootModule hostScopeWithFile)
          ]
          ++ extraModules;
        };

      docsFor =
        system:
        import ./docs {
          inherit lib semanticScopeOptions;
          pkgs = pkgsFor system;
          source = self;
          configurations = self.nixosConfigurations;
        };

      docsCommandsFor =
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          build = pkgs.writeShellApplication {
            name = "docs";
            runtimeInputs = [
              pkgs.git
              pkgs.nix
            ];
            text = ''
              repo="$(git rev-parse --show-toplevel)"
              exec nix build "path:$repo#docs" "$@"
            '';
          };
          serve = pkgs.writeShellApplication {
            name = "docs-serve";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.git
              pkgs.mdbook
              pkgs.nix
              pkgs.rsync
              pkgs.watchexec
            ];
            text = builtins.readFile ./scripts/docs-serve;
          };
        };
    in
    {
      lib.semanticScopeOptions = semanticScopeOptions;

      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);

      packages = forAllSystems (
        system:
        let
          generatedDocs = docsFor system;
        in
        {
          docs = generatedDocs.book;
          docs-source = generatedDocs.docsSource;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system;
          preCommit = preCommitFor system;
          docsCommands = docsCommandsFor system;
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
            exec nix flake check "$@"
          '';

          commonTools =
            with pkgs;
            [
              nixfmt
              nixd
              nil
              statix
              deadnix
              nixdoc
              jq
              skopeo
            ]
            ++ [
              checkRepo
              formatRepo
              repoOptionsFzf
              treefmt.config.build.wrapper
              docsCommands.build
              docsCommands.serve
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
          treefmt = treefmtFor system;
          semanticTest = import ./tests/semantic-scopes.nix { inherit inputs system; };
          semanticPortabilityTest = import ./tests/semantic-system-portability.nix { inherit inputs; };
          semanticOptionsTest = import ./tests/semantic-options.nix {
            inherit inputs;
            configurations = self.nixosConfigurations;
          };
          serverAppStandardsTest = import ./tests/server-app-standards.nix {
            inherit inputs;
            configuration = self.nixosConfigurations.nixos-server;
          };
        in
        {
          nixos-eval = builtins.deepSeq (builtins.mapAttrs (
            _: host: host.config.system.build.bootStage2.drvPath
          ) self.nixosConfigurations) pkgs.emptyFile;
          nixos-server-vm-eval = builtins.seq self.nixosConfigurations.nixos-server.config.system.build.vm.drvPath pkgs.emptyFile;
          docs = self.packages.${system}.docs;
          repo-quality = treefmt.config.build.check self;
          server-app-standards = builtins.seq serverAppStandardsTest pkgs.emptyFile;
          semantic-system-portability = builtins.seq semanticPortabilityTest pkgs.emptyFile;
          semantic-options = builtins.seq semanticOptionsTest pkgs.emptyFile;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          semantic-scopes = builtins.seq semanticTest pkgs.emptyFile;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system;
          docsCommands = docsCommandsFor system;
          plasmaRc2nix = lib.attrByPath [ system "rc2nix" ] null inputs.plasma-manager.packages;

          updateContainerLock = pkgs.writeShellApplication {
            name = "update-container-lock";
            runtimeInputs = with pkgs; [
              coreutils
              diffutils
              git
              jq
              skopeo
            ];
            text = builtins.readFile ./scripts/update-container-lock;
          };

          systemUpgrade = pkgs.writeShellApplication {
            name = "system-upgrade";
            runtimeInputs = [
              pkgs.fzf
              pkgs.git
              pkgs.jq
              updateContainerLock
            ];
            text = ''
              cd "$(git rev-parse --show-toplevel)"

              case "$#:''${1-}" in
                0:)
                  selections=$(
                    set +o pipefail
                    {
                      printf 'all\tUpdate all inputs and containers\n'
                      printf 'all-inputs\tUpdate all inputs\n'
                      printf 'all-containers\tUpdate all containers\n'
                      nix flake metadata --json --no-update-lock-file \
                        | jq -r '.locks.nodes[.locks.root].inputs | keys[] | ["input", .] | @tsv'
                      update-container-lock --list | jq -Rr '["container", .] | @tsv'
                    } | fzf --multi --no-sort --layout=reverse --delimiter=$'\t' --with-nth=2 \
                      --header='Tab: select multiple • Enter: upgrade'
                  ) || exit 0
                  ;;
                1:--all) selections=$'all\t*' ;;
                *) echo "usage: system-upgrade [--all]" >&2; exit 1 ;;
              esac

              inputs=()
              containers=()
              while IFS=$'\t' read -r kind name; do
                case "$kind" in
                  all) inputs=("*"); containers=("*"); break ;;
                  all-inputs) inputs=("*") ;;
                  all-containers) containers=("*") ;;
                  input) [[ ''${inputs[0]-} == "*" ]] || inputs+=("$name") ;;
                  container) [[ ''${containers[0]-} == "*" ]] || containers+=("$name") ;;
                esac
              done <<<"$selections"

              if ((''${#inputs[@]})); then
                [[ ''${inputs[0]} == "*" ]] && inputs=()
                nix flake update "''${inputs[@]}"
              fi

              if ((''${#containers[@]})); then
                [[ ''${containers[0]} == "*" ]] && containers=()
                update-container-lock "''${containers[@]}"
              fi

              nix flake check --no-update-lock-file
            '';
          };

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
        {
          docs-serve = {
            type = "app";
            program = lib.getExe docsCommands.serve;
            meta.description = "Build and live-preview the generated repository manual";
          };
          system-upgrade = {
            type = "app";
            program = lib.getExe systemUpgrade;
            meta.description = "Update Nix inputs and container locks, then check the flake";
          };
          update-container-lock = {
            type = "app";
            program = lib.getExe updateContainerLock;
            meta.description = "Refresh immutable OCI container image digests";
          };
        }
        // lib.optionalAttrs (updatePlasma != null) {
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
            meta.description = "Launch the configured VS Code-compatible editor";
          };
        }
      );
      nixosConfigurations = lib.mapAttrs nixosHost {
        nixos = {
          system = "x86_64-linux";
          hostModule = ./hosts/nixos;
        };

        nixos-arm-parallels = {
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-arm-parallels;
        };

        nixos-orbstack = {
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-orbstack;
        };

        nixos-server = {
          nixpkgsInput = nixpkgs-stable;
          homeManagerInput = home-manager-stable;
          stylixInput = stylix-stable;
          system = "x86_64-linux";
          hostModule = ./hosts/nixos-server;
        };
      };
    };
}
