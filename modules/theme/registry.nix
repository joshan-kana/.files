{ lib, pkgs }:

let
  monaspace = {
    package = pkgs.monaspace;
    name = "Monaspace Neon Frozen";
  };

  # Theme packs are presentation-only. Variants recursively override these shared defaults.
  defaults = {
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

    fonts = {
      serif = monaspace;
      sansSerif = monaspace;
      monospace = monaspace;
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    polarity = "dark";

    shell = {
      panelOpacity = 0.99;
      focusOpacity = 0.96;
      scrimOpacity = 0.50;
      squircleExponent = 4.5;
    };
  };

  variants = {
    carbon = {
      label = "Carbon";
      palette = ./palettes/carbon.yaml;
    };

    catppuccin-mocha = {
      label = "Catppuccin Mocha";
      palette = ./palettes/catppuccin-mocha.yaml;
    };

    dracula = {
      label = "Dracula";
      palette = ./palettes/dracula.yaml;
    };

    gruvbox-material = {
      label = "Gruvbox Material";
      palette = ./palettes/gruvbox-material.yaml;
    };

    kanagawa = {
      label = "Kanagawa";
      palette = ./palettes/kanagawa.yaml;
    };

    neon = {
      label = "Neon";
      palette = ./palettes/neon.yaml;
      shell = {
        panelOpacity = 0.95;
        focusOpacity = 0.92;
        scrimOpacity = 0.44;
        squircleExponent = 5.0;
      };
    };

    nord = {
      label = "Nord";
      palette = ./palettes/nord.yaml;
    };

    rose = {
      label = "Rose";
      palette = ./palettes/rose.yaml;
      polarity = "light";
    };

    rose-pine = {
      label = "Rosé Pine";
      palette = ./palettes/rose-pine.yaml;
    };

    tokyo-night = {
      label = "Tokyo Night";
      palette = ./palettes/tokyo-night.yaml;
    };

    wallpaper = {
      label = "Wallpaper";
      palette = ./palettes/wallpaper.yaml;
      wallpaperSha256 = "3aa9b8f969babc2f23b3a7d7161f99969450b0ded06e7fef9092bab7722d2423";
    };
  };
in
{
  default = "carbon";
  inherit defaults variants;

  resolve = name: lib.recursiveUpdate defaults variants.${name};
}
