{ inputs, ... }:
{
  nixpkgs.overlays = [
    (final: _prev: {
      configarr =
        inputs.configarr.packages.${final.stdenv.hostPlatform.system}.default.overrideAttrs
          (old: {
            src = inputs.configarr;
            inherit (old) version;
            pnpmDeps = old.pnpmDeps.override {
              hash = "sha256-ovhyQU2ffrG/G4n4uWjvFUaWrKwEeuwwcme+NY1CMgI=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = true;
            };
          });
    })
  ];
}
