_:
let
  upstream = builtins.getFlake "github:NixOS/nixpkgs/1c89083e451e891152365b799595cf7790a43325";
in
{
  nixpkgs.overlays = [
    (final: _prev: {
      codex = upstream.legacyPackages.${final.stdenv.hostPlatform.system}.codex.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
