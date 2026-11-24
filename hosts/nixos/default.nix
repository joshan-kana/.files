{
  extendScope,
  lib,
  moduleRegistry,
  pkgs,
  ...
}:

lib.recursiveUpdate (import ../../profiles/workstation.nix { inherit moduleRegistry; }) {
  dotfiles.rebuild.flags = "--impure";

  hardware = import ./hardware.nix;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  cli = extendScope moduleRegistry.cli {
    nvtop = _: {
      home = _: {
        home.packages = [ pkgs.nvtopPackages.full ];
      };
    };

    intelGpuTools = _: {
      home = _: {
        home.packages = [ pkgs.intel-gpu-tools ];
      };
    };
  };
}
