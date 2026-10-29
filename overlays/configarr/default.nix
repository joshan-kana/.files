{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}:
let
  inherit (lib.systems.elaborate system) isLinux;
  schemaType = (import ../lib/schemas { inherit inputs lib; }).configarr;
  yaml = pkgs.formats.yaml { tags = true; };
  configFile = yaml.generate "configarr.yml" (stripNulls config.services.configarr.settings);
  stripNulls =
    value:
    if builtins.isAttrs value then
      builtins.mapAttrs (_: stripNulls) (lib.filterAttrs (_: v: v != null) value)
    else if builtins.isList value then
      map stripNulls value
    else
      value;
in
{
  imports = lib.optionals isLinux [ inputs.configarr.nixosModules.default ];

  options = lib.optionalAttrs isLinux {
    services.configarr.settings = lib.mkOption {
      type = schemaType;
      default = { };
      description = "Configarr configuration, typed from the pinned upstream Zod input schema.";
    };

    services.configarr.generatedConfigFile = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
    };
  };

  config = lib.optionalAttrs isLinux {
    nixpkgs.overlays = [
      (final: _prev: {
        configarr = inputs.configarr.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];

    services.configarr.generatedConfigFile = configFile;
    systemd.services.configarr.preStart = lib.mkIf config.services.configarr.enable (
      lib.mkForce ''
        install -D -m 0644 ${configFile} ${config.services.configarr.dataDir}/config/config.yml
        chown ${config.services.configarr.user}:${config.services.configarr.group} ${config.services.configarr.dataDir}/config/config.yml
      ''
    );
  };
}
