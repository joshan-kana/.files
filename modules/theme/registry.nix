{ pkgs }:

{
  default = "carbon";

  assets = {
    wallpaper = ./wallpaper.png;

    cursor = {
      package = pkgs.google-cursor;
      name = "GoogleDot-Black";
      size = 30;
    };

    icons = {
      package = pkgs.gruvbox-dark-icons-gtk;
      name = "oomox-gruvbox-dark";
    };
  };

  variants = {
    carbon = {
      label = "Carbon";
      scheme = ./palettes/carbon.yaml;
    };

    catppuccin-mocha = {
      label = "Catppuccin Mocha";
      scheme = ./palettes/catppuccin-mocha.yaml;
    };

    dracula = {
      label = "Dracula";
      scheme = ./palettes/dracula.yaml;
    };

    everforest-dark = {
      label = "Everforest Dark";
      scheme = ./palettes/everforest-dark.yaml;
    };

    gruvbox-material = {
      label = "Gruvbox Material";
      scheme = ./palettes/gruvbox-material.yaml;
    };

    kanagawa = {
      label = "Kanagawa";
      scheme = ./palettes/kanagawa.yaml;
    };

    neon = {
      label = "Neon";
      scheme = ./palettes/neon.yaml;
    };

    nord = {
      label = "Nord";
      scheme = ./palettes/nord.yaml;
    };

    rose = {
      label = "Rose";
      scheme = ./palettes/rose.yaml;
      polarity = "light";
    };

    rose-pine = {
      label = "Rosé Pine";
      scheme = ./palettes/rose-pine.yaml;
    };

    tokyo-night = {
      label = "Tokyo Night";
      scheme = ./palettes/tokyo-night.yaml;
    };

    wallpaper = {
      label = "Wallpaper";
      scheme = ./palettes/wallpaper.yaml;
      wallpaperSha256 = "3aa9b8f969babc2f23b3a7d7161f99969450b0ded06e7fef9092bab7722d2423";
    };
  };
}
