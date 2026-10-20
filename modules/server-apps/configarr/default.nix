{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
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
  options.services.configarr.settings = lib.mkOption {
    type = typed schema;
    default = { };
    description = "Configarr configuration, typed from the pinned upstream Zod input schema.";
  };

  config.services.configarr.config = lib.mkIf config.services.configarr.enable (
    builtins.readFile (yaml.generate "configarr.yml" (stripNulls config.services.configarr.settings))
  );
}
