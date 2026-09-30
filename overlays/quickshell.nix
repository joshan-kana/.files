_:

{
  nixpkgs.overlays = [
    (_final: prev: {
      quickshell = prev.quickshell.overrideAttrs (old: {
        version = "${old.version}-patched";
        __intentionallyOverridingVersion = true;

        patches = (old.patches or [ ]) ++ [
          ../patches/quickshell/networkmanager-restart.patch
        ];
      });
    })
  ];
}
