{ lib, ... }:

{
  warnings = [
    (lib.concatStringsSep "
" [
      "hosts/nixos/hardware.nix is a placeholder for pure evaluation only. Do not deploy the nixos x86 host until the real generated hardware config is restored."
      ""
      "Run on the target x86 NixOS machine:"
      ""
      "  cd ~/.files && run0 nixos-generate-config --show-hardware-config > hosts/nixos/hardware.nix"
    ])
  ];

  # Replace this with the real desktop hardware config before rebuilding the
  # `nixos` host:
  #
  #   run0 nixos-generate-config --show-hardware-config > hosts/nixos/hardware.nix
  #
  # The original x86 machine is currently unavailable, so this file is only an
  # eval placeholder.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [
      "compress=zstd"
      "noatime"
    ];
  };
}
