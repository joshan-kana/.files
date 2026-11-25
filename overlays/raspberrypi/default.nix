{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        inherit (inputs.nixos-raspberrypi.packages.aarch64-linux) linuxPackages_rpi4;
        raspberrypifw-rpi4 = inputs.nixos-raspberrypi.packages.aarch64-linux.raspberrypifw;
      }
    )
  ];
}
