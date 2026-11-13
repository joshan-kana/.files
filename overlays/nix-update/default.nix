_: {
  nixpkgs.overlays = [
    (_final: prev: {
      nix-update = prev.nix-update.overridePythonAttrs (old: {
        version = "1.16.0";
        src =
          (builtins.getFlake "github:Mic92/nix-update/f1312346bf252dc10a0b6f70aae80c0a32395c5c").outPath;
        patches = (old.patches or [ ]) ++ [ ../../patches/nix-update/portable-source-hash.patch ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];
}
