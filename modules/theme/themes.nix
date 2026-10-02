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
      scheme = ./carbon.yaml;
    };

    catppuccin-mocha = {
      label = "Catppuccin Mocha";
      scheme = ./catppuccin-mocha.yaml;
    };

    kanagawa = {
      label = "Kanagawa";
      scheme = ./kanagawa.yaml;
    };

    neon = {
      label = "Neon";
      scheme = ./neon.yaml;
    };

    rose = {
      label = "Rose";
      scheme = ./rose.yaml;
      polarity = "light";
    };

    rose-pine = {
      label = "Rosé Pine";
      scheme = ./rose-pine.yaml;
    };

    tokyo-night = {
      label = "Tokyo Night";
      scheme = ./tokyo-night.yaml;
    };

    wallpaper = {
      label = "Wallpaper";
      scheme = ./wallpaper-base16.yaml;
      wallpaperSha256 = "3aa9b8f969babc2f23b3a7d7161f99969450b0ded06e7fef9092bab7722d2423";
    };
  };
}
