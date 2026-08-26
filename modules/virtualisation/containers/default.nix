{ config, ... }:

{
  virtualisation.docker.enable = true;

  userAccess = _: {
    users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "docker" ];
  };

  # The option-schema hook is statically registered by hosts that use image
  # locking. This child supplies the semantic enable/disable control.
  imageLocking = _: { };
}
