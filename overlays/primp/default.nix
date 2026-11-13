_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Remove once nixpkgs includes NixOS/nixpkgs@b9eb668f72ae.
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pythonFinal: pythonPrev: {
          primp = pythonPrev.primp.overridePythonAttrs (old: {
            __structuredAttrs = true;
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.pkg-config ];
            buildInputs = (old.buildInputs or [ ]) ++ [
              prev.aws-lc
              prev.zstd
            ];
          });
        })
      ];
    })
  ];
}
