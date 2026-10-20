{ lib }:
let
  inherit (lib) types;
  taggedString = types.addCheck (types.attrsOf types.str) (
    value:
    let
      keys = builtins.attrNames value;
    in
    builtins.length keys == 1
    && builtins.elem (builtins.head keys) [
      "!env"
      "!file"
      "!secret"
    ]
  );
  resolveRef =
    root: ref:
    let
      path = lib.splitString "/" (lib.removePrefix "#/" ref);
      decode = lib.replaceStrings [ "~1" "~0" ] [ "/" "~" ];
    in
    lib.foldl' (value: part: value.${decode part}) root path;
  optionsFor =
    root: schema:
    builtins.mapAttrs (
      name: child:
      let
        required = builtins.elem name (schema.required or [ ]);
      in
      lib.mkOption (
        {
          type = if required then fromSchema root child else types.nullOr (fromSchema root child);
          description = child.description or "Configarr setting '${name}' (upstream schema).";
        }
        // lib.optionalAttrs (!required) { default = null; }
      )
    ) (schema.properties or { });
  union =
    variants:
    if variants == [ ] then
      types.anything
    else if builtins.length variants == 1 then
      builtins.head variants
    else
      types.oneOf variants;
  fromSchema =
    root: schema:
    let
      kind = if builtins.isAttrs schema then schema.type or null else null;
    in
    if builtins.isBool schema then
      types.anything
    else if builtins.hasAttr "$ref" schema then
      fromSchema root (resolveRef root schema."$ref")
    else if schema ? enum then
      types.enum schema.enum
    else if schema ? const then
      types.enum [ schema.const ]
    else if schema ? anyOf then
      union (map (fromSchema root) schema.anyOf)
    else if schema ? oneOf then
      union (map (fromSchema root) schema.oneOf)
    else if builtins.isList kind then
      union (map (k: fromSchema root (schema // { type = k; })) kind)
    else if kind == "string" then
      types.either types.str taggedString
    else if kind == "boolean" then
      types.bool
    else if kind == "number" then
      types.number
    else if kind == "integer" then
      types.int
    else if kind == "null" then
      types.enum [ null ]
    else if kind == "array" then
      types.listOf (fromSchema root (schema.items or { }))
    else if kind == "object" || schema ? properties || schema ? additionalProperties then
      if schema ? properties then
        types.submodule {
          options = optionsFor root schema;
          freeformType =
            if (schema.additionalProperties or false) == false then
              null
            else
              fromSchema root schema.additionalProperties;
        }
      else
        types.attrsOf (fromSchema root (schema.additionalProperties or { }))
    else
      types.anything;
in
root: fromSchema root root
