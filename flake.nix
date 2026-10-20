{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: package collections and system modules.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Declarative Sonarr, Radarr, and Prowlarr application configuration.
    # Use the upstream flake and its own dependency lock.
    configarr.url = "github:raydak-labs/configarr";

    # Generated schemas kept outside the tracked configuration tree.
    schema-artifacts = {
      url = "github:joshan-kana/.files/schema-artifacts";
      flake = false;
    };

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

    # Upstream nh CLI.
    nh = {
      url = "github:nix-community/nh";
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

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          # Lint the same Quickshell version that hosts actually deploy.
          overlays = (import ./overlays/quickshell { }).nixpkgs.overlays;
        };

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
            "--extend-enable"
            "MD060"
            "--config"
            "MD060.style = \"aligned\""
          ];
          typosConfig = pkgs.writeText "typos.toml" ''
            [default.extend-words]
            hass = "hass"
          '';
        in
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";

          programs = {
            clang-format = {
              enable = true;
              includes = [ "modules/desktop/hyprland/shell/spectrum/*" ];
            };
            deadnix.enable = true;
            csharpier.enable = true;
            nixfmt.enable = true;
            prettier.enable = true;
            qmlformat = {
              enable = true;
              includes = [ "modules/desktop/hyprland/shell/qml/*.qml" ];
            };
            shfmt.enable = true;
            stylua.enable = true;
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
                "tests/**/*.sh"
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
              clang-format.priority = 1;
              prettier.priority = 1;
              quick-lint-js = {
                command = lib.getExe pkgs.quick-lint-js;
                includes = [ "modules/desktop/hyprland/shell/qml/*.js" ];
                priority = 2;
              };

              qml-lint = {
                command = lib.getExe' pkgs.kdePackages.qtdeclarative "qmllint";
                includes = [ "modules/desktop/hyprland/shell/qml/*.qml" ];
                options =
                  lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                    "--max-warnings"
                    "0"
                  ]
                  ++ [
                    "-I"
                    "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml"
                  ]
                  ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
                    "-I"
                    "${pkgs.quickshell}/lib/qt-6/qml"
                  ];
                priority = 2;
              };

              ruff-check.options = [
                "--isolated"
                "--select"
                "E4,E7,E9,F,I"
              ];
              ruff-format.priority = 1;

              prettier.excludes = [ "*.md" ];
              rumdl-format.options = markdownOptions;
              rumdl-check = {
                options = lib.mkForce ([ "check" ] ++ markdownOptions);
                priority = 2;
              };
              typos.priority = 1;
              cppcheck = {
                command = lib.getExe' pkgs.cppcheck "cppcheck";
                priority = 2;
                includes = [
                  "modules/desktop/hyprland/shell/spectrum/*.c"
                  "modules/desktop/hyprland/shell/spectrum/*.cc"
                  "modules/desktop/hyprland/shell/spectrum/*.cpp"
                  "modules/desktop/hyprland/shell/spectrum/*.h"
                  "modules/desktop/hyprland/shell/spectrum/*.hh"
                  "modules/desktop/hyprland/shell/spectrum/*.hpp"
                ];
                options = [
                  "--enable=warning,style,performance,portability"
                  "--error-exitcode=1"
                  "--quiet"
                ];
              };
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
              csharp-lint = {
                command = lib.getExe pkgs.dotnet-sdk_10;
                options = [
                  "format"
                  "analyzers"
                  "--verify-no-changes"
                  "--severity"
                  "warn"
                ];
                includes = [ "*.csproj" ];
                # dotnet format accepts one project at a time.
                no-positional-arg-support = true;
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
              files = "\\.(c|cc|cpp|h|hh|hpp|js|cs|csproj|lock|lua|md|nix|py|qml|sh|ya?ml)$|^\\.editorconfig$|^\\.envrc$|^scripts/";
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
                      configurationFlakeSubdirectory = "modules/theme";
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

      # Derive update candidates from the registered overlays and package metadata.
      updatePackagesFor =
        system:
        lib.foldl'
          (
            packages: cfg:
            if cfg.pkgs.stdenv.hostPlatform.system != system then
              packages
            else
              let
                names = lib.unique (
                  lib.concatMap (overlay: builtins.attrNames (overlay cfg.pkgs cfg.pkgs)) cfg.config.nixpkgs.overlays
                );
                updateable = lib.filterAttrs (
                  name: package:
                  let
                    # Some unrelated nixpkgs overlay attributes fail when forced.
                    policy = builtins.tryEval (package.passthru.autoUpdate or null);
                  in
                  if !policy.success || policy.value == null then
                    false
                  else
                    assert lib.assertMsg (builtins.isBool policy.value)
                      "Package ${name}: passthru.autoUpdate must be a Boolean.";
                    true
                ) (lib.genAttrs names (name: cfg.pkgs.${name}));
              in
              packages // updateable
          )
          { }
          ((builtins.attrValues self.nixosConfigurations) ++ (builtins.attrValues self.darwinConfigurations));

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
        schemaRegistry = (import ./lib/schemas { inherit inputs lib; }).registry;
        updateablePackages = forAllSystems (system: builtins.attrNames (updatePackagesFor system));
        routinePackageUpdates = forAllSystems (
          system:
          lib.filter (name: (updatePackagesFor system).${name}.passthru.autoUpdate) (
            builtins.attrNames (updatePackagesFor system)
          )
        );
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
        // updatePackagesFor system
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
          roaming-dns-build =
            let
              matchingHost = lib.findFirst (host: host.pkgs.stdenv.hostPlatform.system == system) null (
                builtins.attrValues self.nixosConfigurations
              );
            in
            matchingHost.pkgs.technitium-roaming-dns;
          roaming-dns-tests = pkgs.callPackage ./tests/technitium-roaming { };
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

          updateSchemas = pkgs.writeShellApplication {
            name = "update-schemas";
            runtimeInputs = with pkgs; [
              git
              jq
            ];
            text = builtins.readFile ./scripts/update-schemas;
          };

          buildSystems = pkgs.writeShellApplication {
            name = "build-systems";
            runtimeInputs = [
              pkgs.git
              pkgs.jq
              pkgs.rom
            ];
            text = builtins.readFile ./scripts/build-systems;
          };

          systemUpdate = pkgs.writeShellApplication {
            name = "system-update";
            runtimeInputs = [
              pkgs.fzf
              pkgs.git
              pkgs.jq
              updateContainerLock
              updateSchemas
              pkgs.nix-update
              pkgs.python3
            ];
            text = builtins.readFile ./scripts/system-update;
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
          build-systems = {
            type = "app";
            program = lib.getExe buildSystems;
            meta.description = "Build all system configurations";
          };
          system-update = {
            type = "app";
            program = lib.getExe systemUpdate;
            meta.description = "Update inputs, packages, schemas and containers, then check the flake";
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
          update-schemas = {
            type = "app";
            program = lib.getExe updateSchemas;
            meta.description = "Refresh generated schemas for locked upstream revisions";
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
