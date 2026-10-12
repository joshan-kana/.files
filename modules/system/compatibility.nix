{ lib, system, ... }:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  nativeStateVersion =
    if isDarwin then
      6
    else if isLinux then
      "23.05"
    else
      throw "Unsupported host system: ${system}";
in
{
  system.stateVersion = lib.mkDefault nativeStateVersion;

  home = _: {
    home.stateVersion = "23.05";
  };
}
