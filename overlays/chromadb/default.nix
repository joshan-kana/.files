_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # Remove once nixpkgs includes NixOS/nixpkgs@00434ec4230f.
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pythonFinal: pythonPrev: {
          chromadb = pythonPrev.chromadb.overridePythonAttrs (old: {
            buildInputs = (old.buildInputs or [ ]) ++ [
              prev.sqlite
              prev.rust-jemalloc-sys
            ];
          });
        })
      ];
    })
  ];
}
