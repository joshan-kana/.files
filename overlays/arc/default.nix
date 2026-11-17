_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        arc =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "1.173.1";
                build = "90936";
                hash = "sha256-GOWD31SLe/P6BRZgUDNX9irkyloegQO4MGtQl1e1amw=";
              };
              pname = "arc";
              appName = "Arc.app";
              homepage = "https://arc.net";
              license = prev.lib.licenses.unfree;
              passthru = {
                autoUpdate = false;
                updateFilename = "overlays/arc/default.nix";
              };
              url = r: "https://releases.arc.net/release/Arc-${r.version}-${r.build}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
