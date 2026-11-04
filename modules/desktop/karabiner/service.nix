{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.karabiner-elements;
in
{
  # The upstream service still uses the pre-15 launchd layout. Modern
  # Karabiner registers its background components using SMAppService.
  disabledModules = [
    "${inputs.nix-darwin}/modules/services/karabiner-elements"
  ];

  options.services.karabiner-elements = {
    enable = lib.mkEnableOption "Karabiner-Elements";
    package = lib.mkPackageOption pkgs "karabiner-elements" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      installedVersion=$(/usr/sbin/pkgutil --pkg-info org.pqrs.Karabiner-Elements 2>/dev/null | /usr/bin/awk '/^version:/ { print $2 }')
      if [[ "$installedVersion" != "${cfg.package.version}" ]] || [[ ! -d /Applications/Karabiner-Elements.app ]]; then
        echo "Installing Karabiner-Elements ${cfg.package.version}..."
        /usr/sbin/installer \
          -pkg "${cfg.package}/share/karabiner-elements/Karabiner-Elements.pkg" \
          -target /
      fi
    '';
  };
}
