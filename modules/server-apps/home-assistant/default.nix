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

  homeAssistantPkgs = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  homeAssistantPackage = homeAssistantPkgs.home-assistant;
  homeAssistantPython = homeAssistantPackage.python3Packages.python;
  homeAssistantRuntimePythonPath = lib.concatStringsSep ":" [
    "${configDir}/deps"
    "${homeAssistantPackage}/${homeAssistantPython.sitePackages}"
    (homeAssistantPackage.python3Packages.makePythonPath homeAssistantPackage.dependencies)
    config.services.home-assistant.finalPackage.pythonPath
  ];

  brevillePatch = pkgs.writeShellScript "breville-airactive3d-3speed" ''
    file=${configDir}/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml
    [ -f "$file" ] || exit 0

    ${pkgs.gnused}/bin/sed -n \
      '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/p' "$file" \
      | ${pkgs.gnugrep}/bin/grep -q '^[[:space:]]*max:[[:space:]]*3[[:space:]]*$' \
      && exit 0

    ${pkgs.gnused}/bin/sed -i -E \
      '/^[[:space:]]*-[[:space:]]*id:[[:space:]]*3[[:space:]]*$/,/^[[:space:]]*-[[:space:]]*id:/ s/^([[:space:]]*max:[[:space:]]*)[0-9]+/\13/' "$file"
  '';

  # Keep nixpkgs-provided built-in requirements authoritative while allowing
  # Home Assistant and HACS to install requirements missing from the Nix runtime.
  homeAssistantLauncher = pkgs.writeShellScript "home-assistant-native" ''
    exec ${homeAssistantPython}/bin/python -c '
    import sys
    from importlib.metadata import distributions

    from packaging.utils import canonicalize_name

    from homeassistant import requirements as requirements_module
    from homeassistant.util import package as package_util

    package_util.is_virtual_env = lambda: False

    nix_managed_packages = {
        canonicalize_name(dist.metadata["Name"])
        for dist in distributions()
        if dist.metadata.get("Name")
        and str(dist.locate_file("")).startswith("/nix/store/")
    }
    original_process_requirements = requirements_module.RequirementsManager.async_process_requirements

    async def process_requirements(self, name, requirements, is_built_in):
        if is_built_in:
            requirements = [
                requirement
                for requirement in requirements
                if (parsed := package_util.parse_requirement_safe(requirement)) is None
                or canonicalize_name(parsed.name) not in nix_managed_packages
            ]
        await original_process_requirements(self, name, requirements, is_built_in)

    requirements_module.RequirementsManager.async_process_requirements = process_requirements

    from homeassistant.__main__ import main

    sys.argv[0] = "hass"
    raise SystemExit(main())
    ' "$@"
  '';
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
        PYTHONNOUSERSITE = "true";
        PYTHONPATH = lib.mkForce homeAssistantRuntimePythonPath;
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

      serviceConfig = {
        ExecStart = lib.mkForce "${homeAssistantLauncher} --config ${configDir}";
        ExecStartPre = [ brevillePatch ];
      };
    };

    services.breville-airactive3d-3speed = {
      serviceConfig = {
        Type = "oneshot";
        User = "hass";
        Group = "hass";
        ExecStart = brevillePatch;
        ExecStartPost = "+${pkgs.systemd}/bin/systemctl try-restart home-assistant.service";
      };
    };

    paths.breville-airactive3d-3speed = {
      wantedBy = [ "paths.target" ];
      pathConfig.PathChanged = "${configDir}/custom_components/tuya_local/devices/breville_airdynamic3d_fan.yaml";
    };

    tmpfiles.rules = [
      "d ${configDir} 0750 hass hass - -"
      "Z ${configDir} - hass hass - -"
      "A+ ${configDir} - - - - g:${appData.group.name}:rwX,d:g:${appData.group.name}:rwx"
    ];
  };

  virtualisation.vmVariant.services.home-assistant.enable = lib.mkForce false;
}
