{ lib, pkgs, ... }:

{
  networking.hostName = lib.mkForce "nixos-server-vm";

  users.users.joshan.initialPassword = "test";

  services.homeAssistantStack = {
    snapshots.enable = false;
    backups.enable = false;
  };

  virtualisation.vmVariant = {
    virtualisation = {
      cores = lib.mkForce 2;
      memorySize = lib.mkForce 4096;
      diskSize = 8192;
    };

    environment.systemPackages = with pkgs; [
      qemu
    ];
  };
}
