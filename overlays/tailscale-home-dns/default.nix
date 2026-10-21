_: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        tailscale-home-dns = final.callPackage ./package.nix { };
      }
    )
  ];
}
