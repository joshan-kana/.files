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
  schemaFile = import ./configarr/schema.nix { inherit inputs pkgs; };
  schema = builtins.fromJSON (builtins.readFile "${schemaFile}/schema.json");
  typed = import ./configarr/json-schema-type.nix { inherit lib; };
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
  };

  config = lib.optionalAttrs isLinux {
    nixpkgs.overlays = [
      (final: _prev: {
        configarr = inputs.configarr.packages.${final.stdenv.hostPlatform.system}.default;
      })
    ];

    services.configarr.config = lib.mkIf config.services.configarr.enable (
      builtins.readFile (yaml.generate "configarr.yml" (stripNulls config.services.configarr.settings))
    );
  };
}
