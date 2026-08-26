{ inputs, pkgs, ... }:

{
  chromium = _: {
    environment.systemPackages = [ pkgs.chromium ];
  };

  zen = _: {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta
    ];
  };

  firefox = _: {
    home = _: {
      stylix.targets.firefox.profileNames = [ "themed" ];
      stylix.targets.firefox.colorTheme.enable = true;
      programs.firefox.profiles.themed.extensions.force = true;
      programs.firefox.configPath = ".mozilla/firefox";
    };
  };

  floorp = _: {
    home = _: {
      stylix.targets.floorp.profileNames = [ "themed" ];
      stylix.targets.floorp.colorTheme.enable = true;
      programs.floorp.profiles.themed.extensions.force = true;
    };
  };
}
