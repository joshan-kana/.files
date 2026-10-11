let
  # These are original palette colors, not Base16 slot names. Keep the
  # compatibility projection and desktop state tokens downstream of this data.
  native =
    {
      label,
      source,
      palette,
    }:
    let
      p = palette;
    in
    {
      inherit label source palette;
      colors = {
        base00 = p.background;
        base01 = p.surface;
        base02 = p.raised;
        base03 = p.outline;
        base04 = p.muted;
        base05 = p.text;
        base06 = p.strong;
        base07 = p.highlight;
        base08 = p.red;
        base09 = p.orange;
        base0A = p.yellow;
        base0B = p.green;
        base0C = p.cyan;
        base0D = p.blue;
        base0E = p.purple;
        base0F = p.extra;
      };
      ui = {
        inherit (p) background;
        inherit (p) surface;
        surfaceRaised = p.raised;
        inherit (p) outline;
        textMuted = p.secondary or p.muted;
        inherit (p) text;
        textStrong = p.strong;
        critical = p.red;
        warning = p.yellow;
        positive = p.green;
        accent = p.accent or p.blue;
        notificationPaused = p.paused;
        reducedMotion = p.motion;
      };
    };
in
{
  catppuccin-mocha = native {
    label = "Catppuccin Mocha";
    source = "https://github.com/catppuccin/palette";
    palette = {
      background = "1e1e2e"; # base
      surface = "181825"; # mantle
      raised = "313244"; # surface0
      outline = "45475a"; # surface1
      muted = "585b70"; # surface2 (Base16 neutral)
      secondary = "a6adc8"; # subtext0 (UI secondary text)
      text = "cdd6f4"; # text
      strong = "f5e0dc"; # rosewater
      highlight = "b4befe"; # lavender
      red = "f38ba8";
      orange = "fab387"; # peach
      yellow = "f9e2af";
      green = "a6e3a1";
      cyan = "94e2d5"; # teal
      blue = "89b4fa";
      purple = "cba6f7"; # mauve
      extra = "f2cdcd"; # flamingo
      paused = "fab387";
      motion = "cba6f7";
    };
  };

  dracula = native {
    label = "Dracula";
    source = "https://draculatheme.com/contribute";
    palette = {
      background = "282a36";
      surface = "363447"; # intermediate panel, not a named upstream swatch
      raised = "44475a"; # current line / selection
      outline = "6272a4"; # comment
      muted = "9ea8c7"; # softened comment for legible secondary text
      text = "f8f8f2";
      strong = "f8f8f2";
      highlight = "ffffff";
      red = "ff5555";
      orange = "ffb86c";
      yellow = "f1fa8c";
      green = "50fa7b";
      cyan = "8be9fd";
      blue = "bd93f9"; # purple is Dracula's primary cool accent
      purple = "ff79c6"; # pink
      extra = "bd93f9";
      paused = "ffb86c";
      motion = "ff79c6";
    };
  };

  gruvbox-material = native {
    label = "Gruvbox Material";
    source = "https://github.com/sainnhe/gruvbox-material";
    palette = {
      background = "292828";
      surface = "32302f";
      raised = "504945";
      outline = "665c54";
      muted = "bdae93";
      text = "ddc7a1";
      strong = "ebdbb2";
      highlight = "fbf1c7";
      red = "ea6962";
      orange = "e78a4e";
      yellow = "d8a657";
      green = "a9b665";
      cyan = "89b482";
      blue = "7daea3";
      purple = "d3869b";
      extra = "bd6f3e";
      paused = "e78a4e";
      motion = "d3869b";
    };
  };

  kanagawa = native {
    label = "Kanagawa";
    source = "https://github.com/rebelot/kanagawa.nvim/blob/master/lua/kanagawa/colors.lua";
    palette = {
      background = "1f1f28"; # sumiInk3 (Wave)
      surface = "16161d"; # sumiInk0
      raised = "2a2a37"; # sumiInk4
      outline = "54546d"; # sumiInk6
      muted = "727169"; # fujiGray
      text = "dcd7ba"; # fujiWhite
      strong = "dcd7ba";
      highlight = "c8c093"; # oldWhite
      red = "c34043"; # autumnRed
      orange = "ffa066"; # surimiOrange
      yellow = "c0a36e"; # boatYellow2
      green = "76946a"; # autumnGreen
      cyan = "6a9589"; # waveAqua1
      blue = "7e9cd8"; # crystalBlue
      purple = "957fb8"; # oniViolet
      extra = "d27e99"; # sakuraPink
      paused = "ffa066";
      motion = "957fb8";
    };
  };

  nord = native {
    label = "Nord";
    source = "https://www.nordtheme.com/docs/colors-and-palettes";
    palette = {
      background = "2e3440"; # nord0
      surface = "3b4252"; # nord1
      raised = "434c5e"; # nord2
      outline = "4c566a"; # nord3
      muted = "d8dee9"; # nord4
      text = "e5e9f0"; # nord5
      strong = "eceff4"; # nord6
      highlight = "8fbcbb"; # nord7
      red = "bf616a"; # nord11
      orange = "d08770"; # nord12
      yellow = "ebcb8b"; # nord13
      green = "a3be8c"; # nord14
      cyan = "88c0d0"; # nord8
      blue = "81a1c1"; # nord9
      purple = "b48ead"; # nord15
      extra = "5e81ac"; # nord10
      paused = "d08770";
      motion = "b48ead";
    };
  };

  rose-pine = native {
    label = "Rosé Pine";
    source = "https://github.com/rose-pine/neovim/blob/main/lua/rose-pine/palette.lua";
    palette = {
      background = "191724"; # base
      surface = "1f1d2e"; # surface
      raised = "26233a"; # overlay
      outline = "524f67"; # highlightHigh
      muted = "908caa"; # subtle
      text = "e0def4";
      strong = "e0def4";
      highlight = "403d52"; # highlightMed
      red = "eb6f92"; # love
      orange = "ebbcba"; # rose
      yellow = "f6c177"; # gold
      green = "95b1ac"; # leaf
      cyan = "31748f"; # pine
      blue = "9ccfd8"; # foam
      purple = "c4a7e7"; # iris
      extra = "6e6a86"; # muted
      accent = "c4a7e7"; # iris
      paused = "ebbcba";
      motion = "9ccfd8"; # foam
    };
  };

  tokyo-night = native {
    label = "Tokyo Night";
    source = "https://github.com/folke/tokyonight.nvim/blob/main/extras/lua/tokyonight_night.lua";
    palette = {
      background = "1a1b26"; # bg (Night, not Storm)
      surface = "16161e"; # bg_dark
      raised = "292e42"; # bg_highlight
      outline = "545c7e"; # dark3
      muted = "a9b1d6"; # fg_dark
      text = "c0caf5"; # fg
      strong = "c0caf5";
      highlight = "737aa2"; # dark5
      red = "f7768e";
      orange = "ff9e64";
      yellow = "e0af68";
      green = "9ece6a";
      cyan = "7dcfff";
      blue = "7aa2f7";
      purple = "bb9af7";
      extra = "9d7cd8";
      paused = "ff9e64";
      motion = "bb9af7";
    };
  };
}
