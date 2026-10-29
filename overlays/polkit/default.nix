_: {
  nixpkgs.overlays = [
    (
      _: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        polkitWithHybridCgroup =
          let
            version = "127";
          in
          prev.polkit.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitHub {
              owner = "polkit-org";
              repo = "polkit";
              rev = version;
              hash = "sha256-YTugETy0rqu/bv53jV1UeGqSK79bRXR52EJNcTblvzo=";
            };
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
            # Find the cgroup v2 entry even when a v1 controller is also mounted.
            patches = (old.patches or [ ]) ++ [ ./fix-hybrid-cgroup-auth-cache.patch ];
          });
      }
    )
  ];
}
