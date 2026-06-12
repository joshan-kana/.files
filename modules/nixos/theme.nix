{
  config,
  lib,
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

        gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          gtk4.theme = config.gtk.theme;

          iconTheme = {
            package = pkgs.gruvbox-dark-icons-gtk;
            name = "oomox-gruvbox-dark";
          };
        };
      }
    )
  ];
}
