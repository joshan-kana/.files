{
  description = "My first flake!";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    stylix = {
      url = "github:danth/stylix";
    };
  };

  outputs = { self, nixpkgs, stylix, ... }:
    let
      lib = nixpkgs.lib;
    in {
      nixosConfigurations = {
        nixos = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ stylix.nixosModules.stylix ./configuration.nix ];
        };
      };
  };
}
