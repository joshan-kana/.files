{ config, ... }: {
  home-manager = {
    backupFileExtension = "before-nix";
    extraSpecialArgs.configurationName = config.dotfiles.profile.name;
    sharedModules = [ ../options ];
  };
}
