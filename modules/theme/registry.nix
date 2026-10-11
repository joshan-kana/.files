{
  lib,
  pkgs ? null,
}:

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

    catppuccin-mocha = {
      label = "Catppuccin Mocha";
      colors = {
        base00 = "1e1e2e";
        base01 = "181825";
        base02 = "313244";
        base03 = "45475a";
        base04 = "a6adc8";
        base05 = "cdd6f4";
        base06 = "cdd6f4";
        base07 = "a6adc8";
        base08 = "f38ba8";
        base09 = "fab387";
        base0A = "f9e2af";
        base0B = "a6e3a1";
        base0C = "94e2d5";
        base0D = "89b4fa";
        base0E = "f5c2e7";
        base0F = "f2cdcd";
      };
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
      colors = {
        base00 = "282a36";
        base01 = "343746";
        base02 = "44475a";
        base03 = "6272a4";
        base04 = "6272a4";
        base05 = "f8f8f2";
        base06 = "f8f8f2";
        base07 = "f8f8f2";
        base08 = "ff5555";
        base09 = "ffb86c";
        base0A = "f1fa8c";
        base0B = "50fa7b";
        base0C = "8be9fd";
        base0D = "bd93f9";
        base0E = "ff79c6";
        base0F = "bd93f9";
      };
    };

    gruvbox-material = {
      label = "Gruvbox Material";
      colors = {
        base00 = "282828";
        base01 = "32302f";
        base02 = "504945";
        base03 = "665c54";
        base04 = "d4be98";
        base05 = "ddc7a1";
        base06 = "ebdbb2";
        base07 = "fbf1c7";
        base08 = "ea6962";
        base09 = "e78a4e";
        base0A = "d8a657";
        base0B = "a9b665";
        base0C = "89b482";
        base0D = "7daea3";
        base0E = "d3869b";
        base0F = "e78a4e";
      };
    };

    kanagawa = {
      label = "Kanagawa";
      colors = {
        base00 = "1f1f28";
        base01 = "16161d";
        base02 = "223249";
        base03 = "54546d";
        base04 = "727169";
        base05 = "dcd7ba";
        base06 = "dcd7ba";
        base07 = "dcd7ba";
        base08 = "c34043";
        base09 = "ffa066";
        base0A = "c0a36e";
        base0B = "76946a";
        base0C = "6a9589";
        base0D = "7e9cd8";
        base0E = "957fb8";
        base0F = "d27e99";
      };
    };

    neon = {
      label = "Neon";
      colors = {
        base00 = "111111";
        base01 = "1a1a1a";
        base02 = "3a3a3a";
        base03 = "505050";
        base04 = "999999";
        base05 = "ffffff";
        base06 = "ffffff";
        base07 = "ffffff";
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

    nord = {
      label = "Nord";
      colors = {
        base00 = "2e3440";
        base01 = "3b4252";
        base02 = "434c5e";
        base03 = "4c566a";
        base04 = "d8dee9";
        base05 = "e5e9f0";
        base06 = "eceff4";
        base07 = "eceff4";
        base08 = "bf616a";
        base09 = "d08770";
        base0A = "ebcb8b";
        base0B = "a3be8c";
        base0C = "88c0d0";
        base0D = "81a1c1";
        base0E = "b48ead";
        base0F = "5e81ac";
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

    rose-pine = {
      label = "Rosé Pine";
      colors = {
        base00 = "191724";
        base01 = "1f1d2e";
        base02 = "26233a";
        base03 = "6e6a86";
        base04 = "908caa";
        base05 = "e0def4";
        base06 = "e0def4";
        base07 = "e0def4";
        base08 = "eb6f92";
        base09 = "ebbcba";
        base0A = "f6c177";
        base0B = "95b1ac";
        base0C = "31748f";
        base0D = "9ccfd8";
        base0E = "c4a7e7";
        base0F = "eb6f92";
      };
    };

    tokyo-night = {
      label = "Tokyo Night";
      colors = {
        base00 = "1a1b26";
        base01 = "16161e";
        base02 = "292e42";
        base03 = "565f89";
        base04 = "a9b1d6";
        base05 = "c0caf5";
        base06 = "c0caf5";
        base07 = "c0caf5";
        base08 = "f7768e";
        base09 = "ff9e64";
        base0A = "e0af68";
        base0B = "9ece6a";
        base0C = "7dcfff";
        base0D = "7aa2f7";
        base0E = "bb9af7";
        base0F = "9d7cd8";
      };
    };

    wallpaper = {
      label = "Wallpaper";
    };

  };
in
{
  default = "carbon";
  inherit defaults variants;

  resolve = name: lib.recursiveUpdate defaults variants.${name};
}
