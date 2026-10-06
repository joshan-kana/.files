{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: package collections and system modules.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Declarative Sonarr, Radarr, and Prowlarr application configuration.
    # Use the upstream flake and its own dependency lock.
    configarr.url = "github:raydak-labs/configarr";

    # TRaSH custom-format definitions, pinned by flake.lock.
    trash-guides = {
      url = "github:TRaSH-Guides/Guides";
      flake = false;
    };

    # Hermes Agent: packaged agent and service integration.
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt AI agent packages.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # OpenClaw: packaged service integration.
    nix-openclaw.url = "github:openclaw/nix-openclaw";

    # Stylix: declarative themes and typography.
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin: declarative macOS system configuration.
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Package metadata for upstream macOS application bundles.
    homebrew-cask = {
      url = "github:Homebrew/homebrew-cask";
      flake = false;
    };

    # Home Manager: declarative user configuration.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
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

    # Determinate Nix CLI and manual pages.
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

    cosmic-noir-icons = {
      url = "file+https://github.com/atraxsrc/cosmic-icon-themes/releases/latest/download/Cosmic-Noir-Orange.tar.xz";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      stylix,
      treefmt-nix,
      pre-commit-hooks,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;

      semantic = import ./lib/semantic-scopes.nix { inherit lib; };
      semanticScopeOptions = import ./modules/options/semantic-scopes.nix { inherit lib; };
      moduleRegistry = import ./modules;

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

      gitAttributesText =
        "# Generated from flake.nix repoToolExcludedDirs.\n"
        + lib.concatMapStringsSep "\n" (dir: "${dir}** -whitespace") repoToolExcludedDirs
        + "\n";

      treefmtExcludes = map (dir: "${dir}**") repoToolExcludedDirs;
      preCommitExcludes = map (dir: "^${lib.escapeRegex dir}") repoToolExcludedDirs;

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
            qmlformat.enable = true;
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

              qmlformat.priority = 1;
              qml-lint = {
                command = lib.getExe' pkgs.kdePackages.qtdeclarative "qmllint";
                includes = [ "*.qml" ];
                options = [
                  "-I"
                  "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml"
                ]
                ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                  "-I"
                  "${pkgs.quickshell}/lib/qt-6/qml"
                ]
                ++ [
                  "--unqualified"
                  "disable"
                  "--missing-property"
                  "disable"
                  "--missing-type"
                  "disable"
                  "--required"
                  "disable"
                  "--unresolved-type"
                  "disable"
                  "--unused-imports"
                  "disable"
                  "--uncreatable-type"
                  "disable"
                  "--signal-handler-parameters"
                  "disable"
                  "--import"
                  "disable"
                  "--max-warnings"
                  "0"
                ];
                priority = 2;
              };

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
              lua-lint = {
                command = lib.getExe pkgs.lua54Packages.luacheck;
                includes = [ "*.lua" ];
                priority = 2;
              };
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
              files = "\\.(lock|md|nix|py|qml|sh|ya?ml)$|^\\.envrc$|^scripts/";
              excludes = preCommitExcludes;
              pass_filenames = false;
            };

            staged-whitespace = {
              enable = true;
              name = "Staged whitespace";
              entry = "${lib.getExe pkgs.git} diff --cached --check";
              pass_filenames = false;
              always_run = true;
            };
          };
        };

      mkHost =
        configurationName:
        {
          system,
          hostModule,
          moduleRegistryInput ? moduleRegistry,
          configurationOutputName ? configurationName,
          configurationFlakeSubdirectory ? null,
          extraModules ? [ ],
        }:
        let
          inherit (lib.systems.elaborate system) isDarwin isLinux;
          nativeModules =
            if isDarwin then
              "darwinModules"
            else if isLinux then
              "nixosModules"
            else
              throw "Unsupported host system: ${system}";
          hostFile =
            if builtins.pathExists (hostModule + "/default.nix") then
              hostModule + "/default.nix"
            else
              hostModule;
          host = import hostFile;
          systemConstructor =
            if isDarwin then
              nix-darwin.lib.darwinSystem
            else if isLinux then
              nixpkgs.lib.nixosSystem
            else
              throw "Unsupported host system: ${system}";
        in
        systemConstructor {
          inherit system;
          specialArgs = {
            inherit
              configurationName
              configurationOutputName
              configurationFlakeSubdirectory
              inputs
              system
              ;
            inherit (semantic) editScope extendScope;
            moduleRegistry = moduleRegistryInput;
          };
          modules = [
            ./modules/options
            stylix.${nativeModules}.stylix
            home-manager.${nativeModules}.home-manager
            ./overlays
            (semantic.rootModule (
              lib.setFunctionArgs (args: (host args) // { _file = toString hostFile; }) (lib.functionArgs host)
            ))
          ]
          ++ extraModules;
        };

      hostSpecs = {
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
          system = "x86_64-linux";
          hostModule = ./hosts/nixos-server;
        };

        mac = {
          system = "aarch64-darwin";
          hostModule = ./hosts/mac;
        };
      };

      nixosHostSpecs = lib.filterAttrs (_: spec: (lib.systems.elaborate spec.system).isLinux) hostSpecs;
      darwinHostSpecs = lib.filterAttrs (_: spec: (lib.systems.elaborate spec.system).isDarwin) hostSpecs;

      themeNames = builtins.attrNames (import ./modules/theme/registry.nix { inherit lib; }).variants;

      themedConfigurations =
        specs:
        builtins.listToAttrs (
          lib.concatLists (
            lib.mapAttrsToList (
              configurationName: hostSpec:
              map (
                themeName:
                let
                  outputName = "${configurationName}-${themeName}";
                in
                {
                  name = outputName;
                  value = mkHost configurationName (
                    hostSpec
                    // {
                      moduleRegistryInput = moduleRegistry // {
                        theme = semantic.editScope moduleRegistry.theme {
                          name = themeName;
                        };
                      };
                      configurationOutputName = outputName;
                      configurationFlakeSubdirectory = "themes";
                    }
                  );
                }
              ) themeNames
            ) specs
          )
        );
      themedNixosConfigurations = themedConfigurations nixosHostSpecs;
      themedDarwinConfigurations = themedConfigurations darwinHostSpecs;

      docsFor =
        system:
        import ./docs {
          inherit lib semanticScopeOptions;
          pkgs = pkgsFor system;
          source = self;
          configurations = self.nixosConfigurations;
          inherit (self) darwinConfigurations;
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
      lib = {
        inherit semanticScopeOptions themedNixosConfigurations themedDarwinConfigurations;
      };

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
          docs = self.packages.${system}.docs;
          repo-quality = treefmt.config.build.check self;
          git-attributes =
            assert lib.assertMsg (
              builtins.readFile ./.gitattributes == gitAttributesText
            ) "Stale .gitattributes; run nix run .#update-git-attributes";
            pkgs.emptyFile;
          server-app-standards = builtins.seq serverAppStandardsTest pkgs.emptyFile;
          semantic-system-portability = builtins.seq semanticPortabilityTest pkgs.emptyFile;
          semantic-options = builtins.seq semanticOptionsTest pkgs.emptyFile;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          darwin-eval = builtins.seq self.darwinConfigurations.mac.config.system.build.toplevel.drvPath pkgs.emptyFile;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          shell-access =
            pkgs.runCommand "shell-access-tests"
              {
                nativeBuildInputs = with pkgs; [
                  python3
                  bash
                  procps
                ];
              }
              ''
                export HOME="$TMPDIR"
                python3 ${./tests/test-chatgpt-shell-access.py} ${./modules/server-apps/agent-tools/chatgpt-shell-access/chatgpt-shell-access.py}
                touch "$out"
              '';
          nixos-server-vm-eval = builtins.seq self.nixosConfigurations.nixos-server.config.system.build.vm.drvPath pkgs.emptyFile;
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

          systemUpdate = pkgs.writeShellApplication {
            name = "system-update";
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
                      --header='Tab: select multiple • Enter: update'
                  ) || exit 0
                  ;;
                1:--all) selections=$'all\t*' ;;
                *) echo "usage: system-update [--all]" >&2; exit 1 ;;
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

          themeWarm = pkgs.writeShellApplication {
            name = "theme-warm";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.nix
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.systemd ];
            text = ''
              background=false
              maxConfigs=6
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  -b|--background) background=true; shift ;;
                  --max-configs)
                    if [ "$#" -lt 2 ] || [[ ! "$2" =~ ^(0|[1-9][0-9]*)$ ]]; then
                      echo "Expected a non-negative number after --max-configs (0 means unlimited)" >&2
                      exit 2
                    fi
                    maxConfigs="$2"
                    shift 2
                    ;;
                  *) break ;;
                esac
              done
              host="$(hostname -s)"
              if [ "$#" -gt 0 ] && [[ "$1" != -* ]]; then
                host="$1"
                shift
              fi
              case "$host" in
                ${
                  lib.concatStringsSep "|" (
                    lib.attrNames (lib.filterAttrs (_: spec: spec.system == system) hostSpecs)
                  )
                }) ;;
                *) printf 'Unknown host for ${system}: %s\n' "$host" >&2; exit 2 ;;
              esac

              cacheDir="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/theme-cache/$host"
              mkdir -p "$cacheDir"
              if [ "$background" = true ]; then
                ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
                  exec systemd-run --user --collect --unit=dotfiles-theme-warm \
                    --property=Nice=10 --property=IOSchedulingClass=idle \
                    -- "$0" --max-configs "$maxConfigs" "$host" "$@"
                ''}
                ${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
                  exec launchctl submit -l dotfiles.theme-warm \
                    -o "$cacheDir/warm.log" -e "$cacheDir/warm.err" \
                    -- "$0" --max-configs "$maxConfigs" "$host" "$@"
                ''}
              fi

              targets=()
              batch=0
              buildBatch() {
                nix build "$@" --out-link "$cacheDir/batch-$batch" "''${targets[@]}"
                targets=()
                batch=$((batch + 1))
              }
              for theme in ${lib.escapeShellArgs themeNames}; do
                targets+=("path:${self.outPath}#lib.${
                  if pkgs.stdenv.hostPlatform.isDarwin then
                    "themedDarwinConfigurations"
                  else
                    "themedNixosConfigurations"
                }.$host-$theme.config.system.build.toplevel")
                if [ "$maxConfigs" -ne 0 ] && [ "''${#targets[@]}" -ge "$maxConfigs" ]; then
                  buildBatch "$@"
                fi
              done
              if [ "''${#targets[@]}" -gt 0 ]; then
                buildBatch "$@"
              fi
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
          system-update = {
            type = "app";
            program = lib.getExe systemUpdate;
            meta.description = "Update Nix inputs and container locks, then check the flake";
          };
          update-git-attributes = {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "update-git-attributes";
                runtimeInputs = [ pkgs.git ];
                text = ''
                  cp ${pkgs.writeText "gitattributes" gitAttributesText} "$(git rev-parse --show-toplevel)/.gitattributes"
                '';
              }
            );
            meta.description = "Regenerate .gitattributes from repository tool exclusions";
          };
          update-container-lock = {
            type = "app";
            program = lib.getExe updateContainerLock;
            meta.description = "Refresh immutable OCI container image digests";
          };
          theme-warm = {
            type = "app";
            program = lib.getExe themeWarm;
            meta.description = "Build and retain every registered theme for this host";
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
      darwinConfigurations = lib.mapAttrs mkHost darwinHostSpecs;
      nixosConfigurations = lib.mapAttrs mkHost nixosHostSpecs;
    };
}
