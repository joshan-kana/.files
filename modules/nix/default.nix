{ config, ... }:

let
  atticCache = "dotfiles";
  atticEndpoint = "http://192.168.1.3:8080";
  cfg = config.dotfiles;
in
{
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    trusted-users = [
      "root"
      cfg.users.primary.name
    ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "${atticEndpoint}/${atticCache}"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
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
          token-file = "${cfg.secretsDir}/attic-token";
        };
      };
      watchStore = [ atticCache ];
    };
  };

  programs.nix-ld.enable = true;
}
