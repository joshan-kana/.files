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
  schemaFile = import ./schema.nix { inherit inputs pkgs; };
  schema = builtins.fromJSON (builtins.readFile "${schemaFile}/schema.json");
  typed = import ./json-schema-type.nix { inherit lib; };
  yaml = pkgs.formats.yaml { tags = true; };
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
      type = typed schema;
      default = { };
      description = "Configarr configuration, typed from the pinned upstream Zod input schema.";
    };

    services.configarr.generatedConfigFile = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      internal = true;
      description = "Generated Configarr YAML, retaining tagged environment and secret references.";
    };
  };

  config = lib.optionalAttrs isLinux {
    nixpkgs.overlays = [
      (final: _prev: {
        configarr = inputs.configarr.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];

    services.configarr.generatedConfigFile = yaml.generate "configarr.yml" (
      stripNulls config.services.configarr.settings
    );

    systemd.services.configarr.preStart = lib.mkIf config.services.configarr.enable (
      lib.mkForce ''
        install -D -m 0644 ${config.services.configarr.generatedConfigFile} ${config.services.configarr.dataDir}/config/config.yml
        chown ${config.services.configarr.user}:${config.services.configarr.group} ${config.services.configarr.dataDir}/config/config.yml
      ''
    );
  };
}
