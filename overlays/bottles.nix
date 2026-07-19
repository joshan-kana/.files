_:

{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        pinned = builtins.getFlake "github:NixOS/nixpkgs/293d6abedf0478e681a4dfcfcb35b30fc796a32f";
      in
      {
        bottles = pinned.legacyPackages.${prev.system}.bottles;
      }
    )
  ];
}
