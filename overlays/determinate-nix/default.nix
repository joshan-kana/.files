{ inputs, ... }: {
  nixpkgs.overlays = [
    (final: _prev: {
      determinate-nix-cli =
        inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.nix-cli.overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
      determinate-nix-manpages =
        inputs.determinate-nix.packages.${final.stdenv.hostPlatform.system}.nix-manual-manpages-only.overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
    })
  ];
}
