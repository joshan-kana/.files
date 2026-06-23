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

    # Home Manager: a tool for managing dotfiles using Nix
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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nixos-hardware,
      home-manager,
      stylix,
      spicetify-nix,
      plasma-manager,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f system);

      pkgsFor = system: import nixpkgs { inherit system; };

      repoFormatterFor =
        pkgs:
        pkgs.writeShellApplication {
          name = "treefmt";
          runtimeInputs = [
            pkgs.nixfmt
            pkgs.treefmt
          ];
          text = ''
            exec treefmt "$@"
          '';
        };

      gitHookSetup = ''
        git config --local core.hooksPath .githooks
        chmod +x .githooks/pre-commit
      '';

      nixosHost =
        {
          system,
          hostModule,
          nixpkgsInput ? nixpkgs,
          extraModules ? [ ],
        }:
        nixpkgsInput.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            ./overlays/monaspace-liga-overlay.nix
            ./modules/nixos/theme.nix
            hostModule
          ]
          ++ extraModules;
        };
    in
    {
      formatter = forAllSystems (system: repoFormatterFor (pkgsFor system));

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          repoOptionsFzf = pkgs.writeShellApplication {
            name = "no";
            runtimeInputs = with pkgs; [
              fzf
              git
              jq
              nix
            ];
            text = ''
              repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
              exec "$repo/scripts/nix-options-fzf" "$@"
            '';
          };

          commonTools =
            with pkgs;
            [
              nixfmt
              treefmt
              nixd
              nil
              statix
              deadnix
            ]
            ++ [ repoOptionsFzf ];

          vscodePkg =
            if pkgs ? vscodium then
              pkgs.vscodium
            else if pkgs ? vscode then
              pkgs.vscode
            else
              null;
        in
        {
          default = pkgs.mkShell {
            packages = commonTools;
            shellHook = gitHookSetup;
          };

          vscode = pkgs.mkShell {
            packages = commonTools ++ lib.optionals (vscodePkg != null) [ vscodePkg ];
            shellHook = gitHookSetup;
          };
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          vscodePkg =
            if pkgs ? vscodium then
              pkgs.vscodium
            else if pkgs ? vscode then
              pkgs.vscode
            else
              null;
        in
        lib.optionalAttrs (vscodePkg != null) {
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
          system = "aarch64-linux";
          hostModule = ./hosts/nixos-server;
        };
      };
    };
}
