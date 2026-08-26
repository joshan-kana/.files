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
        "x86_64-darwin"
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
        treefmt-nix.lib.evalModule (pkgsFor system) {
          projectRootFile = "flake.nix";

          programs = {
            deadnix.enable = true;
            nixfmt.enable = true;
            statix = {
              enable = true;
              disabled-lints = [ "repeated_keys" ];
            };
          };

          settings = {
            excludes = treefmtExcludes;

            # Apply semantic fixes before the final formatting pass.
            formatter = {
              deadnix.priority = 1;
              statix.priority = 2;
              nixfmt.priority = 3;
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
            nix-quality = {
              enable = true;
              name = "Nix formatting and linting";
              entry = "${lib.getExe pkgs.nix} build --no-link .#checks.${system}.nix-quality";
              files = "\\.nix$";
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
        nixpkgsInput.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            stylixInput.nixosModules.stylix
            homeManagerInput.nixosModules.home-manager
            (semantic.systemModule "monaspaceLiga" (import ./overlays/monaspace-liga-overlay.nix))
            (semantic.systemModule "bottles" (import ./overlays/bottles.nix))
            (semantic.systemModule "ghDash" (import ./overlays/gh-dash.nix))
            (semantic.systemModule "theme" (import ./modules/nixos/theme.nix))
            (semantic.systemModule "resticCompletions" (import ./modules/nixos/restic-completions.nix))
            (semantic.rootModule (import hostModule))
          ]
          ++ extraModules;
        };
    in
    {
      formatter = forAllSystems (system: (treefmtFor system).config.build.wrapper);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system;
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
          treefmt = treefmtFor system;
          semanticTest = import ./tests/semantic-scopes.nix { inherit inputs system; };
        in
        {
          nix-quality = treefmt.config.build.check self;
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          semantic-scopes = pkgs.writeText "semantic-scopes-test.json" (builtins.toJSON semanticTest);
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          treefmt = treefmtFor system;
          fixNix = pkgs.writeShellApplication {
            name = "fix-nix";
            runtimeInputs = [ treefmt.config.build.wrapper ];
            text = ''
              exec treefmt "$@"
            '';
          };

          vscodePkg = pkgs.vscodium or (pkgs.vscode or null);
        in
        {
          fix = {
            type = "app";
            program = lib.getExe fixNix;
            meta.description = "Apply deadnix, statix, and nixfmt fixes through treefmt";
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
