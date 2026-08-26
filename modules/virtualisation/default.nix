{ config, pkgs, ... }:

{
  containers = import ./containers;

  libvirt = _: {
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    programs.virt-manager.enable = true;

    users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "libvirtd" ];
  };

  quickemu = _: {
    environment.systemPackages = [ pkgs.quickemu ];
  };

  distrobox = _: {
    environment.systemPackages = [ pkgs.distrobox ];
  };

  bottles = _: {
    environment.systemPackages = [ pkgs.bottles ];
  };

  vm = import ./vm.nix;
}
