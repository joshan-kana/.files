_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        nvtopPackages = prev.nvtopPackages // {
          full = prev.nvtopPackages.nvidia; # or whichever variant you need
        };
      }
    )
  ];
}
