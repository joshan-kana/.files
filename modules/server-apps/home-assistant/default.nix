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
    "${configDir}/www/media/ha-bambulab"
  ];

  services.home-assistant = {
    enable = true;
    package = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.home-assistant;
    inherit configDir;
    config = null;

    # Built-in integrations currently managed through Home Assistant.
    extraComponents = [
      "analytics"
      "bluetooth"
      "cast"
      "default_config"
      "dlna_dms"
      "esphome"
      "go2rtc"
      "google_translate"
      "homekit"
      "homekit_controller"
      "ipp"
      "matter"
      "met"
      "mobile_app"
      "radio_browser"
      "rpi_power"
      "samsungtv"
      "shopping_list"
      "sun"
      "thread"
      "upnp"
      "wled"
    ];

    # Requirements declared by the mutable HACS/custom components in configDir.
    extraPackages =
      ps: with ps; [
        aiogithubapi
        beautifulsoup4
        tinytuya
        tuya-device-sharing-sdk
      ];
  };

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

  systemd.tmpfiles.rules = [
    "d ${configDir} 0750 hass hass - -"
    "Z ${configDir} - hass hass - -"
    "A+ ${configDir} - - - - g:${appData.group.name}:rwX,d:g:${appData.group.name}:rwx"
  ];

  users.users.hass.extraGroups = [ appData.group.name ];

  virtualisation.vmVariant.services.home-assistant.enable = lib.mkForce false;
}
