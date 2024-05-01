{ config, pkgs, spicetify-nix, ... }:
{
  # Mopidy (MPD)
  services.mopidy = {
    enable = false;
    extensionPackages = with pkgs; [
      mopidy-mpd
      mopidy-mpris
    ];
    settings = {
      mpd = {
        enabled = true;
        hostname = "127.0.0.1";
        port = "6600";
      };
    };
  };

  # spicetify
  programs.spicetify = {
    enable = false;
    theme = spicetify-nix.packages.${pkgs.system}.default.themes.Dribbblish;
    colorScheme = "custom";

    customColorScheme = {
      text = "${config.lib.stylix.colors.base07}";
      subtext = "${config.lib.stylix.colors.base07}";
      sidebar-text = "${config.lib.stylix.colors.base07}";
      main = "${config.lib.stylix.colors.base00}";
      sidebar = "${config.lib.stylix.colors.base01}";
      player = "${config.lib.stylix.colors.base01}";
      card = "${config.lib.stylix.colors.base01}";
      shadow = "${config.lib.stylix.colors.base00}";
      selected-row = "${config.lib.stylix.colors.base0A}";
      button = "${config.lib.stylix.colors.base0C}";
      button-active = "${config.lib.stylix.colors.base0B}";
      button-disabled = "${config.lib.stylix.colors.base0D}";
      tab-active = "${config.lib.stylix.colors.base04}";
      notification = "${config.lib.stylix.colors.base03}";
      notification-error = "${config.lib.stylix.colors.base08}";
      misc = "${config.lib.stylix.colors.base03}";
    };
  };
}
