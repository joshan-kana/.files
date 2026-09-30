{
  default = "carbon";

  variants = {
    carbon = {
      label = "Carbon";
      scheme = ./carbon.yaml;
    };

    neon = {
      label = "Neon";
      scheme = ./neon.yaml;
    };
  };
}
