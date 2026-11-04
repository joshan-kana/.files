{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.programs) contour;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    ;
  yamlFormat = pkgs.formats.yaml { };
in
{
  options.programs.contour = {
    enable = mkEnableOption "Contour terminal emulator";

    package = mkPackageOption pkgs "contour" { };

    settings = mkOption {
      inherit (yamlFormat) type;
      default = { };
      description = "Contour settings written to contour.yml.";
    };
  };

  config = mkIf contour.enable {
    home.packages = [
      contour.package
      contour.package.terminfo
    ];

    xdg.configFile."contour/contour.yml".source = yamlFormat.generate "contour.yml" contour.settings;
  };
}
