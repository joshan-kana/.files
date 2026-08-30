{
  config,
  pkgs,
  ...
}:

let
  inherit (config.dotfiles) server;
  appDataRoot = server.storage.appData.root;
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
    "${appDataRoot}/home-assistant/www/media/ha-bambulab"
  ];

  systemd.services.docker-home-assistant = {
    after = [
      "bluetooth.service"
      "dbus.service"
    ];
    wants = [
      "bluetooth.service"
      "dbus.service"
    ];
  };

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable";

    volumes = [
      "${appDataRoot}/home-assistant:/config"
      "/run/dbus:/run/dbus:ro"
    ];

    extraOptions = [
      "--network=host"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
    ];
  };

  # fix breville fan 3-speed patch in home assistant
  systemd.services.breville-airactive3d-3speed = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      file=${appDataRoot}/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml
      [ -f "$file" ] || exit 0

      ${pkgs.gnused}/bin/sed -n \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/p' "$file" \
        | ${pkgs.gnugrep}/bin/grep -q '^[[:space:]]*max:[[:space:]]*3[[:space:]]*$' \
        && exit 0

      ${pkgs.gnused}/bin/sed -i -E \
        '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/ s/^([[:space:]]*max:[[:space:]]*)[0-9]+/\13/' "$file"

      ${pkgs.docker}/bin/docker restart home-assistant >/dev/null || true
    '';
  };

  systemd.paths.breville-airactive3d-3speed = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathChanged = "${appDataRoot}/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml";
  };
}
