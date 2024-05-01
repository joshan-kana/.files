{
  description = "My first flake!";

  inputs = {
    # Nixpkgs: a collection of packages for the Nix package manager
    nixpkgs.url = "nixpkgs/nixos-unstable";

    # Stylix: systemwide theming and typography for NixOS
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager: a tool for managing dotfiles using Nix
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Spicetify-nix: a nix flake for the spicetify-cli (theming Spotify)
    spicetify-nix = {
      url = "github:the-argus/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Plasma-manager: a nix flake for managing KDE Plasma
    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, home-manager, stylix, spicetify-nix, plasma-manager, ... }:
    let
      lib = nixpkgs.lib;
    in
    {
      nixosConfigurations = {
        nixos = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                plasma-manager.homeManagerModules.plasma-manager
                spicetify-nix.homeManagerModules.default
                ./home.nix
                ./home_x86.nix
                ./desktop/plasma/plasma.nix
                ./desktop/hyprland/hyprland.nix
              ];

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
              home-manager.extraSpecialArgs = {
                inherit spicetify-nix;
              };
            }
            ./configuration.nix
            ./profile_nixos.nix
            ./configuration_x86.nix
            ./ssh.nix
            /etc/nixos/hardware-configuration.nix
          ];
        };
        nixos-arm = lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            stylix.nixosModules.stylix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                plasma-manager.homeManagerModules.plasma-manager
                spicetify-nix.homeManagerModules.default
                ./home.nix
                ./desktop/plasma/plasma_hm.nix
                ./desktop/hyprland/hyprland.nix
              ];

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
              home-manager.extraSpecialArgs = {
                inherit spicetify-nix;
              };
            }
            ./configuration.nix
            ./profile_nixos-arm.nix
            ./ssh.nix
            ./boot.nix
            ./desktop/plasma/plasma.nix
            /etc/nixos/hardware-configuration.nix
          ];
        };
        nixos-orbstack = lib.nixosSystem {
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

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
            ./configuration.nix
            ./profile_nixos-orbstack.nix
            ./orbstack.nix
          ];
        };
      };
    };
}
