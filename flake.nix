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
    in {
      nixosConfigurations = {
        nixos = lib.nixosSystem {
          specialArgs = { inherit spicetify-nix;};
          system = "x86_64-linux";
          modules = [
            stylix.nixosModules.stylix
            spicetify-nix.nixosModules.default
            home-manager.nixosModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.joshan.imports = [
                plasma-manager.homeManagerModules.plasma-manager
                ./home.nix
              ];

              # Optionally, use home-manager.extraSpecialArgs to pass
              # arguments to home.nix
            }
            ./configuration.nix
          ];
        };
      };
    };
}
