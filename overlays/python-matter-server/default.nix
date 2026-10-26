_: {
  nixpkgs.overlays = [
    (_final: prev: {
      python-matter-server = prev.python-matter-server.overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./skip-invalid-paa-certificates.patch ];
      });
    })
  ];
}
