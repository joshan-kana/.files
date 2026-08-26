_: {
  virtualisation.vmVariant.virtualisation = {
    cores = 4;
    memorySize = 8192;
  };

  aliases = _: {
    home = _: {
      programs.zsh.shellAliases = {
        sysvm = ''sudo nixos-rebuild --flake "$DOTFILES#$FLK_PROFILE" $NIXOS_REBUILD_FLAGS build-vm'';
        svm = ''sudo nixos-rebuild --flake "$DOTFILES#$FLK_PROFILE" $NIXOS_REBUILD_FLAGS build-vm'';
      };
    };
  };
}
