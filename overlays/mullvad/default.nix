_: {
  nixpkgs.overlays = [
    (_: prev: {
      mullvadWithCgroup2 = prev.mullvad.overrideAttrs (old: {
        cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [
          "talpid-core/cgroup2"
          "mullvad-exclude/cgroup2"
        ];
      });
    })
  ];
}
