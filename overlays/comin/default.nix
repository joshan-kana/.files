{
  config,
  lib,
  pkgs,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  upstream = builtins.getFlake "github:nlewo/comin/ed92afc48978fb15a2535ebd5c5f63b3010e3b78";
in
{
  imports =
    lib.optionals isLinux [ upstream.nixosModules.comin ]
    ++ lib.optionals isDarwin [ upstream.darwinModules.comin ];

  options.services.comin.allowForcePush = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether Comin may accept non-fast-forward updates to its main branch.
    '';
  };

  config = lib.mkMerge [
    {
      nixpkgs.overlays = [
        (final: _prev: {
          comin = upstream.packages.${final.stdenv.hostPlatform.system}.comin.overrideAttrs (old: {
            version = "${old.version}-patched";
            __intentionallyOverridingVersion = true;

            patches = (old.patches or [ ]) ++ [
              ../../patches/comin/allow-force-push.patch
            ];
          });
        })
      ];
    }

    (lib.optionalAttrs isLinux (
      lib.mkIf config.services.comin.allowForcePush {
        systemd.services.comin.environment.COMIN_ALLOW_FORCE_PUSH = "true";
      }
    ))
    (lib.optionalAttrs isDarwin {
      # The upstream Comin module reads this option for its executable PATH.
      # With `nix.enable = false`, Determinate still owns the daemon.
      nix.package = lib.mkDefault pkgs.nix;
    })
    (lib.optionalAttrs isDarwin (
      lib.mkIf config.services.comin.allowForcePush {
        launchd.daemons.comin.serviceConfig.EnvironmentVariables.COMIN_ALLOW_FORCE_PUSH = "true";
      }
    ))
  ];
}
