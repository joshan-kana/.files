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
}
