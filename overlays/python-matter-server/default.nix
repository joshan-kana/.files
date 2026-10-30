_: {
  nixpkgs.overlays = [
    (_final: prev: {
      python-matter-server =
        let
          version = "8.1.2";
        in
        prev.python-matter-server.overridePythonAttrs (old: {
          inherit version;
          src = prev.fetchFromGitHub {
            owner = "matter-js";
            repo = "python-matter-server";
            rev = "refs/tags/${version}";
            hash = "sha256-vnI57h/aesnaDYorq1PzcMCLmV0z0ZBJvMg4Nzh1Dtc=";
          };
          passthru =
            (old.passthru or { })
            // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
              autoUpdate = false;
            };
          patches = (old.patches or [ ]) ++ [ ./skip-invalid-paa-certificates.patch ];
        });
    })
  ];
}
