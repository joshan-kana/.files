_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        # Remove once nixpkgs includes the upstream fix for replayed session events.
        crush = prev.crush.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [ ../../patches/crush/replayed-client-session-test.patch ];
          passthru = (old.passthru or { }) // {
            autoUpdate = false;
          };
        });
      }
    )
  ];
}
