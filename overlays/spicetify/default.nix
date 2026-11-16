{
  inputs,
  lib,
  system,
  ...
}:
{
  imports = lib.optionals (system == "x86_64-linux") [
    inputs.spicetify-nix.nixosModules.spicetify
  ];
}
