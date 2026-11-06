{ inputs, ... }:

{
  nixpkgs.overlays = [
    (_final: prev: {
      tuicr = inputs.nixpkgs.legacyPackages.${prev.stdenv.hostPlatform.system}.tuicr.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
