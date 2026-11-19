{ pkgs, ... }@args:

pkgs.callPackage (pkgs.path + "/nixos/lib/make-btrfs-fs.nix") (
  builtins.removeAttrs args [ "pkgs" ] // { fakeroot = pkgs.fakerootBtrfs; }
)
