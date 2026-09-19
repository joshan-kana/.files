{
  config,
  inputs,
  pkgs,
  ...
}:

let
  atticCache = "dotfiles";
  atticEndpoint = "http://192.168.1.3:8080";
  nixBuilderSecret = "${config.dotfiles.server.secretsDir or config.dotfiles.secretsDir}/nix-builder";
in
{
  nixpkgs.config.allowUnfree = true;

  nix.package = inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.nix-cli;

  environment.systemPackages = [
    inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.nix-manual-manpages-only
  ];

  nix.settings = {
    trusted-users = [
      "root"
      config.dotfiles.users.primary.name
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
      "https://cache.numtide.com"
      "${atticEndpoint}/${atticCache}"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "dotfiles:U1NE7k5WM7I0l3losIw3VhG4eUGZAxsSvkw6br7p2iA="
    ];
    require-sigs = true;
    fallback = true;
    builders-use-substitutes = true;
  };

  builders = _: {
    nix = {
      distributedBuilds = true;
      buildMachines = [
        {
          hostName = "Joshans-MacBook-Pro.local";
          protocol = "ssh-ng";
          sshUser = config.dotfiles.users.primary.name;
          sshKey = nixBuilderSecret;
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUltSDMwckd3cm82d0V2UTltQkhoZ1k3TExtbTdjam9ibXcrSUJ2NjdRanEK";
          system = "aarch64-darwin";
          maxJobs = 12;
        }
        {
          hostName = "Joshans-MacBook-Pro.local:32223";
          protocol = "ssh-ng";
          sshUser = config.dotfiles.users.primary.name;
          sshKey = nixBuilderSecret;
          publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUM3bFdSS3h5cXFJWXhSckJ6cU83eU9vcVBKTWQ5R2ZQSU9oUnpMMEpGVUcK";
          system = "aarch64-linux";
          maxJobs = 12;
        }
      ];
    };
  };

  home = _: {
    programs.attic-client = {
      enable = true;
      settings = {
        default-server = "attic";
        servers.attic = {
          endpoint = atticEndpoint;
          token-file = "${config.dotfiles.secretsDir}/attic-token";
        };
      };
      watchStore = [ atticCache ];
    };
  };

  programs.nix-ld.enable = true;
}
