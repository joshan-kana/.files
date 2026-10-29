{ inputs, lib }:
let
  typed = import ./json-schema-type.nix { inherit lib; };
  schemaRoot = inputs.schema-artifacts;
  fromFile = path: typed (builtins.fromJSON (builtins.readFile path));
  fromGenerated =
    name: sourceRevision: generatorHash:
    assert lib.assertMsg
      (
        (lib.removeSuffix "\n" (builtins.readFile (schemaRoot + "/${name}/source-revision")))
        == sourceRevision
      )
      "${name} schema does not match its locked upstream revision; run system-update to refresh schemas";
    assert lib.assertMsg (
      (lib.removeSuffix "\n" (builtins.readFile (schemaRoot + "/${name}/generator-hash")))
      == generatorHash
    ) "${name} schema generator changed; run system-update to refresh schemas";
    fromFile (schemaRoot + "/${name}/schema.json");
in
{
  inherit fromFile fromGenerated;
  configarr = fromGenerated "configarr" inputs.configarr.rev (
    builtins.hashFile "sha256" ../../configarr/export-schema.ts
  );
}
