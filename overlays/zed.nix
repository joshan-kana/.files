_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      zed-editor =
        (builtins.getFlake "github:NixOS/nixpkgs/6510408d147d8c5e6d76043e899e9251756f6a75")
        .legacyPackages.${prev.stdenv.hostPlatform.system}.zed-editor;
    })
  ];
}
