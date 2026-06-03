{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: a collection of packages for the Nix package manager
    nixpkgs.url = "nixpkgs/nixos-unstable";

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

  outputs = { self, nixpkgs, home-manager, stylix, spicetify-nix, plasma-manager, ... } @ inputs:
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

      repoFormatterFor = pkgs:
        pkgs.writeShellApplication {
          name = "nixfmt";
          runtimeInputs = [
            pkgs.git
            pkgs.nixfmt
          ];
          text = ''
            if [ "$#" -gt 0 ]; then
              exec nixfmt "$@"
            fi

            git ls-files -z '*.nix' | xargs -0 nixfmt
          '';
        };

      # Centralised profile-specific variables
      profiles = {
        nixos = {
          dotfilesPath = "/home/joshan/.files";
          profileName = "nixos";
          ollamaUrl = "http://localhost:11434/v1";
          nixosRebuildFlags = "--impure";
        };

        nixos-arm-parallels = {
          dotfilesPath = "/home/joshan/.files";
          profileName = "nixos-arm-parallels";
          ollamaUrl = "http://localhost:11434/v1";
          nixosRebuildFlags = "";
        };

        nixos-orbstack = {
          dotfilesPath = "/Users/joshan/.files";
          profileName = "nixos-orbstack";
          ollamaUrl = "http://host.orb.internal:11434/v1";
          nixosRebuildFlags = "--impure";
        };
      };
    in
    {
      formatter = forAllSystems (system: repoFormatterFor (pkgsFor system));

      devShells = forAllSystems (
        system: let
          pkgs = pkgsFor system;
          commonTools = with pkgs; [
            nixfmt
            nixd
            nil
            statix
            deadnix
          ];

          vscodePkg =
            if pkgs ? vscodium
            then pkgs.vscodium
            else if pkgs ? vscode
            then pkgs.vscode
            else null;
        in {
          default = pkgs.mkShell {
            packages = commonTools;
          };

          vscode = pkgs.mkShell {
            packages = commonTools ++ lib.optionals (vscodePkg != null) [vscodePkg];
          };
        }
      );

      apps = forAllSystems (
        system: let
          pkgs = pkgsFor system;
          vscodePkg =
            if pkgs ? vscodium
            then pkgs.vscodium
            else if pkgs ? vscode
            then pkgs.vscode
            else null;
        in
          lib.optionalAttrs (vscodePkg != null) {
            code = {
              type = "app";
              program = lib.getExe vscodePkg;
            };
          }
      );

      nixosConfigurations = {
        nixos = let
          specialArgs = {
            inherit inputs;
            inherit (profiles.nixos) dotfilesPath profileName ollamaUrl nixosRebuildFlags;
          };
        in lib.nixosSystem {
          inherit specialArgs;
          system = "x86_64-linux";
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                plasma-manager.homeModules.plasma-manager
                spicetify-nix.homeManagerModules.default
                ./home.nix
                ./profiles/nixos/home_x86.nix
                ./desktop/plasma/plasma_hm.nix
                ./desktop/hyprland/hyprland.nix
              ];

              home-manager.extraSpecialArgs = specialArgs // { inherit spicetify-nix; };
            }
            ./overlays/nvtop-overlay.nix
            ./overlays/monaspace-liga-overlay.nix
            ./configuration.nix
            ./profiles/nixos/profile_nixos.nix
            ./profiles/nixos/configuration_x86.nix
            ./ssh.nix
            ./vpn.nix
            ./boot.nix
            ./desktop/display-manager.nix
            ./desktop/hyprland/hyprland_nixos.nix
            ./desktop/plasma/plasma.nix
            /etc/nixos/hardware-configuration.nix
          ];
        };
        
        nixos-arm-parallels = let
          specialArgs = {
            inherit inputs;
            inherit (profiles.nixos-arm-parallels) dotfilesPath profileName ollamaUrl nixosRebuildFlags;
          };
        in lib.nixosSystem {
          inherit specialArgs;
          system = "aarch64-linux";
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                plasma-manager.homeModules.plasma-manager
                spicetify-nix.homeManagerModules.default
                ./home.nix
                ./desktop/plasma/plasma_hm.nix
                ./desktop/hyprland/hyprland.nix
              ];

              home-manager.extraSpecialArgs = specialArgs // { inherit spicetify-nix; };
            }
            ./overlays/monaspace-liga-overlay.nix
            ./configuration.nix
            ./profiles/nixos-arm-parallels/profile_nixos-arm-parallels.nix
            ./ssh.nix
            ./vpn.nix
            ./boot.nix
            ./desktop/display-manager.nix
            ./desktop/hyprland/hyprland_nixos.nix
            ./desktop/plasma/plasma.nix
            ./profiles/nixos-arm-parallels/hardware-configuration.nix
          ];
        };
        
        nixos-orbstack = let
          specialArgs = {
            inherit inputs;
            inherit (profiles.nixos-orbstack) dotfilesPath profileName ollamaUrl nixosRebuildFlags;
          };
        in lib.nixosSystem {
          inherit specialArgs;
          system = "aarch64-linux";
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                ./home.nix
              ];

              home-manager.extraSpecialArgs = specialArgs // { inherit spicetify-nix; };
            }
            ./overlays/monaspace-liga-overlay.nix
            ./configuration.nix
            ./profiles/nixos-orbstack/profile_nixos-orbstack.nix
            ./orbstack.nix
          ];
        };
      };
    };
}
