{ lib, pkgs }:

let
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

    fonts =
      let
        font = {
          package = pkgs.monaspace;
          name = "Monaspace Neon Frozen";
        };
      in
      {
        serif = font;
        sansSerif = font;
        monospace = font;
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };

    polarity = "dark";
  };

  # Native color roles are authoritative for named upstream themes. Base16 is
  # only the compatibility projection consumed by Stylix and its integrations.
  variants = {
    carbon = {
      label = "Carbon";
      colors = {
        base00 = "111111";
        base01 = "1a1a1a";
        base02 = "3a3a3a";
        base03 = "505050";
        base04 = "d0d0d0";
        base05 = "f0f0f0";
        base06 = "ffffff";
        base07 = "ffffff";
        base08 = "ff7a5c";
        base09 = "ff3366";
        base0A = "ffd24a";
        base0B = "3de5f0";
        base0C = "bde6ff";
        base0D = "33a8ff";
        base0E = "c79cff";
        base0F = "c9664a";
      };
    };

    neon = {
      label = "Neon";
      colors = {
        base00 = "111111";
        base01 = "1a1a1a";
        base02 = "3a3a3a";
        base03 = "505050";
        base04 = "666666";
        base05 = "ffffff";
        base06 = "cccccc";
        base07 = "444444";
        base08 = "fc6a5c";
        base09 = "ffaa00";
        base0A = "ffcc00";
        base0B = "66cc66";
        base0C = "55cccc";
        base0D = "5588cc";
        base0E = "cc55cc";
        base0F = "aa6622";
      };
    };

    rose = {
      label = "Rose";
      polarity = "light";
      colors = {
        base00 = "feedf3";
        base01 = "f8e2e7";
        base02 = "e0ccd1";
        base03 = "755f64";
        base04 = "665055";
        base05 = "564448";
        base06 = "42383a";
        base07 = "33292b";
        base08 = "df2d52";
        base09 = "f6661e";
        base0A = "c29461";
        base0B = "2e916d";
        base0C = "1d8991";
        base0D = "006e93";
        base0E = "5e2180";
        base0F = "ba0d35";
      };
    };

    wallpaper = {
      label = "Wallpaper";
    };
  }
  // (import ./native-palettes.nix);

  # Custom packs predate the native role catalogue. Give them explicit semantic
  # state colors without changing their existing Base16 scheme.
  customUi = colors: {
    background = colors.base00;
    surface = colors.base01;
    surfaceRaised = colors.base02;
    outline = colors.base03;
    textMuted = colors.base04;
    text = colors.base05;
    textStrong = colors.base06;
    critical = colors.base08;
    warning = colors.base0A;
    positive = colors.base0B;
    accent = colors.base0D;
    notificationPaused = colors.base09;
    reducedMotion = colors.base0E;
  };
in
{
  default = "carbon";
  inherit defaults variants;

  resolve =
    name:
    let
      selected = lib.recursiveUpdate defaults variants.${name};
    in
    selected // { ui = selected.ui or (customUi selected.colors); };
}
