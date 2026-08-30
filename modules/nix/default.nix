{
  config,
  inputs,
  pkgs,
  ...
}:

let
  atticCache = "dotfiles";
  atticEndpoint = "http://192.168.1.3:8080";
  inherit (config) dotfiles;
  inherit (dotfiles.users) primary;
in
{
  nixpkgs.config.allowUnfree = true;

  nix.package = inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.default;

  nix.settings = {
    trusted-users = [
      "root"
      primary.name
    ];
    eval-cores = 0;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org/"
      "https://install.determinate.systems"
      "https://nix-community.cachix.org"
      "${atticEndpoint}/${atticCache}"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "dotfiles:U1NE7k5WM7I0l3losIw3VhG4eUGZAxsSvkw6br7p2iA="
    ];
    require-sigs = true;
    fallback = false;
    builders-use-substitutes = true;
  };

  home = _: {
    programs.attic-client = {
      enable = true;
      settings = {
        default-server = "attic";
        servers.attic = {
          endpoint = atticEndpoint;
          token-file = "${dotfiles.secretsDir}/attic-token";
        };
      };
      watchStore = [ atticCache ];
    };
  };

  programs.nix-ld.enable = true;
}
