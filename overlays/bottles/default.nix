_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        bottles =
          if prev.stdenv.hostPlatform.isx86 then
            prev.bottles
          else
            prev.bottles.override {
              bottles-unwrapped = prev.bottles-unwrapped.override {
                umu-launcher = prev.umu-launcher-unwrapped;
              };
            };
      }
    )
  ];
}
