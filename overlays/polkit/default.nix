_: {
  nixpkgs.overlays = [
    (
      _: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        polkitWithHybridCgroup =
          let
            version = "128";
          in
          prev.polkit.overrideAttrs (old: {
            inherit version;
            src = prev.fetchFromGitHub {
              owner = "polkit-org";
              repo = "polkit";
              rev = version;
              hash = "sha256-v9Um2o9/JQQ1LBa/1mtCoiZS3fv8Dif9mdVSwK22EKE=";
            };
            # Release 128 no longer uses /bin/true or /bin/false in its test fixture.
            postPatch =
              builtins.replaceStrings
                [ "--replace-fail /bin/true" "--replace-fail /bin/false" ]
                [ "--replace-warn /bin/true" "--replace-warn /bin/false" ]
                (old.postPatch or "");
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
            # Find the cgroup v2 entry even when a v1 controller is also mounted.
            patches = (old.patches or [ ]) ++ [ ../../patches/polkit/fix-hybrid-cgroup-auth-cache.patch ];
          });
      }
    )
  ];
}
