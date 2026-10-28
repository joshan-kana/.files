_: {
  nixpkgs.overlays = [
    (_: prev: {
      polkitWithHybridCgroup = prev.polkit.overrideAttrs (old: {
        # Find the cgroup v2 entry even when a v1 controller is also mounted.
        patches = (old.patches or [ ]) ++ [ ./fix-hybrid-cgroup-auth-cache.patch ];
      });
    })
  ];
}
