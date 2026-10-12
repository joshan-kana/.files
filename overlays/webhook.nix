_:

{
  nixpkgs.overlays = [
    (final: _prev: {
      webhook =
        (builtins.getFlake "github:NixOS/nixpkgs/c5c4a43b0e8056328ec4529f735cabdb8f1942bb")
        .legacyPackages.${final.stdenv.hostPlatform.system}.webhook.overrideAttrs
          (old: {
            version = "${old.version}-patched";
            __intentionallyOverridingVersion = true;

            patches = (old.patches or [ ]) ++ [
              ../patches/webhook/max-body-size.patch
            ];
          });
    })
  ];
}
