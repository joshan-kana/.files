{ config, lib, ... }:

{
  virtualisation.docker.enable = true;

  # Ordering alone does not pull in Docker during a system switch.
  systemd.services = lib.mkIf (config.virtualisation.oci-containers.backend == "docker") (
    lib.mapAttrs' (
      name: _:
      lib.nameValuePair "docker-${name}" {
        requires = [ "docker.service" ];
      }
    ) config.virtualisation.oci-containers.containers
  );

  userAccess = _: {
    users.users.${config.dotfiles.users.primary.name}.extraGroups = [ "docker" ];
  };

  # The option-schema hook is statically registered by hosts that use image
  # locking. This child supplies the semantic enable/disable control.
  imageLocking = _: { };
}
