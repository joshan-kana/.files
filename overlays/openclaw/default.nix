{
  inputs,
  lib,
  system,
  ...
}:
{
  imports = lib.optionals (lib.systems.elaborate system).isLinux [
    inputs.nix-openclaw.nixosModules.openclaw-gateway
  ];

  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs
        (builtins.hasAttr prev.stdenv.hostPlatform.system inputs.nix-openclaw.packages)
        {
          openclaw-gateway =
            inputs.nix-openclaw.packages.${final.stdenv.hostPlatform.system}.openclaw-gateway;
        }
    )
  ];
}
