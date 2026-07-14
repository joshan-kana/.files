{
  config,
  pkgs,
  ...
}:

{
  stylix = {
    enable = true;
    image = ../../wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/framer.yaml";

    fonts = {
      serif = config.stylix.fonts.monospace;
      sansSerif = config.stylix.fonts.monospace;
      monospace = {
        package = pkgs.monaspace-liga;
        name = "Monaspace Neon";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };

    polarity = "dark";

    cursor = {
      package = pkgs.google-cursor;
      name = "GoogleDot-Black";
      size = 30;
    };
  };

  home-manager.users.${config.dotfiles.users.primary.name}.imports = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:

      {
        # Shared Home Manager theme defaults moved here so all theme policy lives
        # in one module.
        stylix.targets.qt.platform = "kde";
        stylix.targets.vscode.enable = false;

        programs.hunk.settings = {
          theme = "custom";
          custom_theme = with config.lib.stylix.colors.withHashtag; {
            base = if config.stylix.polarity == "light" then "github-light-default" else "github-dark-default";
            label = "Stylix";

            background = base00;
            panel = base01;
            panelAlt = base02;
            border = base03;
            accent = base0D;
            accentMuted = base02;
            text = base05;
            muted = base04;

            addedBg = base01;
            removedBg = base01;
            movedAddedBg = base01;
            movedRemovedBg = base01;
            contextBg = base00;
            addedContentBg = base02;
            removedContentBg = base02;
            contextContentBg = base00;
            addedSignColor = base0B;
            removedSignColor = base08;

            lineNumberBg = base00;
            lineNumberFg = base03;
            selectedHunk = base02;

            badgeAdded = base0B;
            badgeRemoved = base08;
            badgeNeutral = base04;
            fileNew = base0B;
            fileDeleted = base08;
            fileRenamed = base0A;
            fileModified = base0D;
            fileUntracked = base0C;

            noteBorder = base0D;
            noteBackground = base01;
            noteTitleBackground = base02;
            noteTitleText = base05;

            syntax = {
              default = base05;
              keyword = base0E;
              string = base0B;
              comment = base03;
              number = base09;
              function = base0D;
              property = base0C;
              type = base0A;
              variable = base05;
              operator = base0E;
              punctuation = base04;
            };
          };
        };

        gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          gtk4.theme = lib.mkDefault config.gtk.theme;

          iconTheme = {
            package = pkgs.gruvbox-dark-icons-gtk;
            name = "oomox-gruvbox-dark";
          };
        };
      }
    )
  ];
}
