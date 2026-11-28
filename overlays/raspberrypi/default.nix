{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      _: prev:
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.system == "aarch64-linux") {
        raspberrypi = inputs.nixos-raspberrypi.packages.aarch64-linux;
      }
    )
  ];
}
