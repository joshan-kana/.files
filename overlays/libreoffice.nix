_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      libreoffice =
        (builtins.getFlake "github:NixOS/nixpkgs/eaad089433ca2bb662274377d33df3d0e51ef28b")
        .legacyPackages.${prev.stdenv.hostPlatform.system}.libreoffice;
    })
  ];
}
