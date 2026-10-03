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
  };
in
{
  default = "carbon";
  inherit defaults variants;

  resolve = name: lib.recursiveUpdate defaults variants.${name};
}
