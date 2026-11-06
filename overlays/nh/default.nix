{ inputs, ... }:

{
  nixpkgs.overlays = [
    inputs.nh.overlays.default
    (_final: prev: {
      nh = prev.nh.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
