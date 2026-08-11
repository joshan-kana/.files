{
  config,
  pkgs,
  ...
}:

let
  primaryUser = config.dotfiles.users.primary.name;
  serverCfg = config.dotfiles.server;
  inherit (serverCfg) secretsDir;
  appDataRoot = serverCfg.storage.appData.root;

in
{
  imports = [
    ./planning-hubs
  ];

  users.users.${primaryUser}.extraGroups = [ "docker" ];

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
  # Server OCI containers. Images are declared as plain upstream `repository:tag`
  # sources; the global `container-image-locking.nix` module appends the matching
  # locked digest at evaluation time, so these definitions stay in native NixOS
  # OCI-container syntax.
  virtualisation.oci-containers.containers = {
    home-assistant = {
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

    matter-server = {
      image = "ghcr.io/home-assistant-libs/python-matter-server:stable";

      volumes = [ "${appDataRoot}/matter-server:/data" ];

      extraOptions = [
        "--network=host"
        "--cap-add=NET_ADMIN"
        "--cap-add=NET_RAW"
      ];
    };

    n8n = {
      image = "docker.n8n.io/n8nio/n8n:latest";

      volumes = [ "${appDataRoot}/n8n:/home/node/.n8n" ];
      ports = [ "5678:5678" ];

      environment = {
        GENERIC_TIMEZONE = config.time.timeZone;
      };
      environmentFiles = [ "${secretsDir}/n8n.env" ];
    };

  };

  # fix breville fan 3-speed patch in home assistant
  systemd.services.breville-airactive3d-3speed = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      file=/var/lib/apps/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml
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
    pathConfig.PathChanged = "/var/lib/apps/home-assistant/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml";
  };

}
