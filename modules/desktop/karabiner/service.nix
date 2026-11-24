# Karabiner 15+ replaced the launchd services managed by nix-darwin with
# signed SMAppService components installed by the vendor's package.
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
  disabledModules = [ "${inputs.nix-darwin}/modules/services/karabiner-elements" ];

  options.services.karabiner-elements = {
    enable = lib.mkEnableOption "Karabiner-Elements";
    package = lib.mkPackageOption pkgs "karabiner-elements" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = lib.mkAfter ''
      state=/var/db/.files/karabiner-elements
      installedVersion=$(/usr/sbin/pkgutil --pkg-info org.pqrs.Karabiner-Elements 2>/dev/null | /usr/bin/awk '/^version:/ { print $2 }' || true)
      if [[ ! -f "$state" ]] ||
         [[ "$(/bin/cat "$state")" != "${cfg.package}" ]] ||
         [[ "$installedVersion" != "${cfg.package.version}" ]] ||
         [[ ! -d /Applications/Karabiner-Elements.app ]] ||
         [[ ! -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]; then
        if [[ -v DRY_RUN ]]; then
          echo "Would install Karabiner-Elements ${cfg.package.version}"
        else
          /usr/sbin/installer -pkg "${cfg.package}/share/karabiner-elements/Karabiner-Elements.pkg" -target /
          /bin/mkdir -p /var/db/.files
          /usr/bin/printf '%s\n' "${cfg.package}" > "$state"
        fi
      fi
    '';
  };
}
