_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        technitium-roaming-dns = final.callPackage ./package.nix { };
      }
    )
  ];
}
