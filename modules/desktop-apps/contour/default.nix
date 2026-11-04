{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.contour;
  yaml = pkgs.formats.yaml { };
in
{
  options.programs.contour = {
    enable = lib.mkEnableOption "Contour terminal emulator";

    package = lib.mkPackageOption pkgs "contour" { };

    settings = lib.mkOption {
      inherit (yaml) type;
      default = { };
      description = "Contour settings written to contour.yml.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      cfg.package.terminfo
    ];

    xdg.configFile."contour/contour.yml".source = yaml.generate "contour.yml" cfg.settings;
  };
}
