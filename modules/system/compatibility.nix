{ lib, ... }:

{
  system.stateVersion = lib.mkDefault "23.05";

  home = _: {
    home.stateVersion = "23.05";
  };
}
