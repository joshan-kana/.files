_: {
  nixpkgs.overlays = [
    (_final: prev: {
      fakerootBtrfs = prev.fakeroot.overrideAttrs {
        version = "2.1.4";
        src = prev.fetchurl {
          url = "https://deb.debian.org/debian/pool/main/f/fakeroot/fakeroot_2.1.4.orig.tar.xz";
          hash = "sha256-CCK9Wp8M8Z0roFRriLBDLU09mRfbYsV7dARMytugbkk=";
        };
        patches = [ ];
        postUnpack =
          prev.lib.replaceStrings [ "source/scripts/fakeroot.in" ] [ "$sourceRoot/scripts/fakeroot.in" ]
            prev.fakeroot.postUnpack;
      };
    })
  ];
}
