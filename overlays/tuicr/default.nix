_:
let
  upstream = builtins.getFlake "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";
in
{
  nixpkgs.overlays = [
    (final: _prev: {
      tuicr = upstream.legacyPackages.${final.stdenv.hostPlatform.system}.tuicr.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
