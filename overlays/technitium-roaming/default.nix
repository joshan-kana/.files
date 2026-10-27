{ lib, system, ... }: {
  imports = lib.optionals (lib.systems.elaborate system).isLinux [ ./module.nix ];

  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        technitium-roaming-dns = final.callPackage ./package.nix { };
      }
    )
  ];
}
