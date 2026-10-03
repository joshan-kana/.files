{ lib, pkgs }:

let
  monaspace = {
    package = pkgs.monaspace;
    name = "Monaspace Neon Frozen";
  };

  # Theme packs contain only cross-desktop theme data. Application-specific
  # presentation belongs to the semantic scope that owns that application.
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
  };

  variants = {
    carbon = {
      label = "Carbon";
      author = "Framer (darkened bg + saturated by Josh)";
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
      author = "https://github.com/catppuccin/catppuccin";
      colors = {
        base00 = "1e1e2e";
        base01 = "181825";
        base02 = "313244";
        base03 = "45475a";
        base04 = "585b70";
        base05 = "cdd6f4";
        base06 = "f5e0dc";
        base07 = "b4befe";
        base08 = "f38ba8";
        base09 = "fab387";
        base0A = "f9e2af";
        base0B = "a6e3a1";
        base0C = "94e2d5";
        base0D = "89b4fa";
        base0E = "cba6f7";
        base0F = "f2cdcd";
      };
    };

    dracula = {
      label = "Dracula";
      author = "Jamy Golden (http://github.com/JamyGolden), based on Dracula Theme (http://github.com/dracula)";
      colors = {
        base00 = "282a36";
        base01 = "363447";
        base02 = "44475a";
        base03 = "6272a4";
        base04 = "9ea8c7";
        base05 = "f8f8f2";
        base06 = "f0f1f4";
        base07 = "ffffff";
        base08 = "ff5555";
        base09 = "ffb86c";
        base0A = "f1fa8c";
        base0B = "50fa7b";
        base0C = "8be9fd";
        base0D = "80bfff";
        base0E = "ff79c6";
        base0F = "bd93f9";
      };
    };

    gruvbox-material = {
      label = "Gruvbox Material";
      author = "Mayush Kumar (https://github.com/MayushKumar), sainnhe (https://github.com/sainnhe/gruvbox-material-vscode)";
      colors = {
        base00 = "292828";
        base01 = "32302f";
        base02 = "504945";
        base03 = "665c54";
        base04 = "bdae93";
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
        base0F = "bd6f3e";
      };
    };

    kanagawa = {
      label = "Kanagawa";
      author = "Tommaso Laurenzi (https://github.com/rebelot)";
      colors = {
        base00 = "1f1f28";
        base01 = "16161d";
        base02 = "223249";
        base03 = "54546d";
        base04 = "727169";
        base05 = "dcd7ba";
        base06 = "c8c093";
        base07 = "717c7c";
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
      author = "Hybrid: Hammerspoon bg + vscode-framer-2 fg (by Steven Phan & TSUYUSATO Kitsune)";
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

    nord = {
      label = "Nord";
      author = "arcticicestudio";
      colors = {
        base00 = "2e3440";
        base01 = "3b4252";
        base02 = "434c5e";
        base03 = "4c566a";
        base04 = "d8dee9";
        base05 = "e5e9f0";
        base06 = "eceff4";
        base07 = "8fbcbb";
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
      author = "Sakura palette by Misterio77 (http://github.com/Misterio77)";
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
      author = "Emilia Dunfelt <edun@dunfelt.se>";
      colors = {
        base00 = "191724";
        base01 = "1f1d2e";
        base02 = "26233a";
        base03 = "6e6a86";
        base04 = "908caa";
        base05 = "e0def4";
        base06 = "e0def4";
        base07 = "524f67";
        base08 = "eb6f92";
        base09 = "f6c177";
        base0A = "ebbcba";
        base0B = "31748f";
        base0C = "9ccfd8";
        base0D = "c4a7e7";
        base0E = "f6c177";
        base0F = "524f67";
      };
    };

    tokyo-night = {
      label = "Tokyo Night";
      author = "Michaël Ball";
      colors = {
        base00 = "1a1b26";
        base01 = "16161e";
        base02 = "2f3549";
        base03 = "444b6a";
        base04 = "787c99";
        base05 = "a9b1d6";
        base06 = "cbccd1";
        base07 = "d5d6db";
        base08 = "c0caf5";
        base09 = "a9b1d6";
        base0A = "0db9d7";
        base0B = "9ece6a";
        base0C = "b4f9f8";
        base0D = "2ac3de";
        base0E = "bb9af7";
        base0F = "f7768e";
      };
    };

    wallpaper = {
      label = "Wallpaper";
      author = "Stylix palette generator, contrast-adjusted";
      colors = {
        base00 = "191c1d";
        base01 = "252828";
        base02 = "3c3d38";
        base03 = "938775";
        base04 = "baaa93";
        base05 = "b9a58d";
        base06 = "b8a68e";
        base07 = "bba492";
        base08 = "9d8d7e";
        base09 = "a48e77";
        base0A = "ab9484";
        base0B = "a68e7c";
        base0C = "978d82";
        base0D = "a78876";
        base0E = "9c8b77";
        base0F = "ac907a";
      };
    };

  };
in
{
  default = "carbon";
  inherit defaults variants;

  resolve = name: lib.recursiveUpdate defaults variants.${name};
}
