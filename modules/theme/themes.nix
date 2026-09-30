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

    wallpaper = {
      label = "Wallpaper";
      scheme = ./wallpaper-base16.yaml;
      wallpaperSha256 = "3aa9b8f969babc2f23b3a7d7161f99969450b0ded06e7fef9092bab7722d2423";
    };
  };
}
