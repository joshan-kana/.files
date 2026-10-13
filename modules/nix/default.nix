{
  config,
  inputs,
  pkgs,
  lib,
  system,
  ...
}:

let
  atticCache = "dotfiles";
  atticEndpoint = "http://nixos-server.home:8080";
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  settings = {
    trusted-users = [
      "root"
      config.dotfiles.users.primary.name
    ];
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

  nixBuilderSecret = "${config.dotfiles.server.secretsDir or config.dotfiles.secretsDir}/nix-builder";
in
{
  nixpkgs.config.allowUnfree = true;
}
// lib.optionalAttrs isLinux {
  nix.package = inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.nix-cli;
  nix.settings = settings;

  environment.systemPackages = [
    inputs.determinate-nix.packages.${pkgs.stdenv.hostPlatform.system}.nix-manual-manpages-only
  ];

}
// {
  builders =
    _:
    lib.optionalAttrs isLinux {
      nix = {
        distributedBuilds = true;
        buildMachines = [
          {
            hostName = "mac.home";
            protocol = "ssh-ng";
            sshUser = config.dotfiles.users.primary.name;
            sshKey = nixBuilderSecret;
            publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUltSDMwckd3cm82d0V2UTltQkhoZ1k3TExtbTdjam9ibXcrSUJ2NjdRanEK";
            system = "aarch64-darwin";
            maxJobs = 12;
          }
          {
            hostName = "mac.home:32223";
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
}
// lib.optionalAttrs isDarwin {
  nix.enable = false;
  determinateNix.customSettings =
    builtins.removeAttrs settings [
      "substituters"
      "trusted-public-keys"
    ]
    // {
      extra-substituters = settings.substituters;
      extra-trusted-public-keys = settings.trusted-public-keys;
    };
}
// {
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
      watchStore = lib.optionals isLinux [ atticCache ];
    };
    launchd = lib.optionalAttrs isDarwin {
      agents.attic-watch-store = {
        enable = true;
        config = {
          Label = "com.joshankana.attic-watch-store";
          ProgramArguments = [
            "${lib.getExe pkgs.attic-client}"
            "watch-store"
            atticCache
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
        };
      };
    };
  };
}
// lib.optionalAttrs isLinux {
  programs.nix-ld.enable = true;
}
