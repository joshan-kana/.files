{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  inherit (server.storage) appData;
  configDir = "${appData.root}/home-assistant";

  homeAssistantPkgs = inputs.nixpkgs-home-assistant.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  homeAssistantBase = homeAssistantPkgs.home-assistant;
  homeAssistantPackage = (homeAssistantBase.override { skipPip = false; }).overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./allow-runtime-requirements.patch ];
  });
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  environment.systemPackages = [ pkgs.bluez ];

  networking.firewall.interfaces.${server.lan.interface}.allowedTCPPorts = [
    8123
    21064 # HomeKit main bridge
    21065 # HomeKit Bambu camera bridge
  ];

  services.restic.backups.apps.exclude = [
    "${configDir}/deps"
    "${configDir}/www/media/ha-bambulab"
  ];

  services.home-assistant = {
    enable = true;
    package = homeAssistantPackage;
    inherit configDir;
    config = null;
    extraPackages = ps: [ ps.uv ];
  };

  systemd = {
    services.home-assistant = {
      environment = {
        NIXOS_HOME_ASSISTANT_MANAGED_REQUIREMENTS = "1";
        PYTHONPATH = lib.mkForce "${configDir}/deps:${config.services.home-assistant.finalPackage.pythonPath}";
      };
      after = [
        "bluetooth.service"
        "dbus.service"
      ];
      wants = [
        "bluetooth.service"
        "dbus.service"
      ];
      path = [ homeAssistantPkgs.go2rtc ];
    };

    tmpfiles.rules = [
      "d ${configDir} 0750 hass hass - -"
      "d ${configDir}/deps 0750 hass hass - -"
      "Z ${configDir} - hass hass - -"
      "A+ ${configDir} - - - - g:${appData.group.name}:rwX,d:g:${appData.group.name}:rwx"
    ];
  };

  # fix breville fan 3-speed patch in home assistant
  systemd.services.breville-airactive3d-3speed = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      file=${configDir}/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml
      [ -f "$file" ] || exit 0

      ${pkgs.gnused}/bin/sed -n \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/p' "$file" \
        | ${pkgs.gnugrep}/bin/grep -q '^[[:space:]]*max:[[:space:]]*3[[:space:]]*$' \
        && exit 0

      ${pkgs.gnused}/bin/sed -i -E \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/ s/^([[:space:]]*max:[[:space:]]*)[0-9]+/\13/' "$file"

      ${pkgs.systemd}/bin/systemctl try-restart home-assistant.service
    '';
  };

  systemd.paths.breville-airactive3d-3speed = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = "${configDir}/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml";
  };

  virtualisation.vmVariant.services.home-assistant.enable = lib.mkForce false;
}
