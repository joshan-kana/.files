{ lib, system, ... }:
{
  enable = false;
}
// lib.optionalAttrs (lib.systems.elaborate system).isLinux {
  boot.plymouth = {
    enable = true;
    showDelay = 0;
  };
  boot.kernelParams = [ "quiet" ];
}
