_: {
  docker = _: {
    virtualisation.docker.enable = true;
  };

  oci = _: {
    virtualisation.oci-containers.backend = "docker";
  };

  # The option-schema hook is statically registered by hosts that use image
  # locking. This child supplies the semantic enable/disable control.
  imageLocking = _: { };
}
