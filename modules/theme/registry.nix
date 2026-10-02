{
  lib,
  pkgs ? null,
}:

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

    cosmic-noir = {
      # https://github.com/atraxsrc/cosmic-noir-theme
      label = "Cosmic Noir";
      assets.icons = {
        name = "Cosmic-Noir-Orange";
        package = pkgs.cosmic-noir-icons;
      };
      colors = {
        base00 = "171717";
        base01 = "222222";
        base02 = "2a2a2a";
        base03 = "686c69";
        base04 = "a6ada6";
        base05 = "ccd0cf";
        base06 = "dadedd";
        base07 = "dadedd";
        base08 = "f25623";
        base09 = "f56e0f";
        base0A = "aeab94";
        base0B = "88a57d";
        base0C = "959c95";
        base0D = "f25623";
        base0E = "f56e0f";
        base0F = "f0913a";
      };
    };

    dracula = {
      label = "Dracula";
      palette = ./palettes/dracula.yaml;
    };

    everforest-dark = {
      label = "Everforest Dark";
      palette = ./palettes/everforest-dark.yaml;
    };

    gruvbox-material = {
      label = "Gruvbox Material";
      palette = ./palettes/gruvbox-material.yaml;
    };

    kanagawa = {
      label = "Kanagawa";
      palette = ./palettes/kanagawa.yaml;
    };

    macos-dark = {
      label = "macOS Dark";
      colors = {
        base00 = "1c1c1e";
        base01 = "2c2c2e";
        base02 = "3a3a3c";
        base03 = "636366";
        base04 = "aeaeb2";
        base05 = "f2f2f7";
        base06 = "ffffff";
        base07 = "ffffff";
        base08 = "ff453a";
        base09 = "ff9f0a";
        base0A = "ffd60a";
        base0B = "30d158";
        base0C = "64d2ff";
        base0D = "0a84ff";
        base0E = "bf5af2";
        base0F = "ff375f";
      };
    };

    macos-light = {
      label = "macOS Light";
      polarity = "light";
      colors = {
        base00 = "f5f5f7";
        base01 = "e9e9ed";
        base02 = "d6d6dc";
        base03 = "77777f";
        base04 = "5c5c64";
        base05 = "242428";
        base06 = "1d1d1f";
        base07 = "111113";
        base08 = "d92d20";
        base09 = "b85d00";
        base0A = "976500";
        base0B = "248a3d";
        base0C = "008c95";
        base0D = "007aff";
        base0E = "af52de";
        base0F = "c5275f";
      };
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
