{
  config,
  lib,
  ...
}:

let
  upstream = builtins.getFlake "github:nlewo/comin/ed92afc48978fb15a2535ebd5c5f63b3010e3b78";
in
{
  imports = [ upstream.nixosModules.comin ];

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
              ../patches/comin/allow-force-push.patch
            ];
          });
        })
      ];
    }

    (lib.mkIf config.services.comin.allowForcePush {
      systemd.services.comin.environment.COMIN_ALLOW_FORCE_PUSH = "true";
    })
  ];
}
