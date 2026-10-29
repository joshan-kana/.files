{ inputs, lib }:
let
  typed = import ./json-schema-type.nix { inherit lib; };
  registry = builtins.fromJSON (builtins.readFile ./registry.json);
  repo = ../../..;
  generatorHash =
    entry:
    builtins.hashString "sha256" (
      lib.concatMapStringsSep "" (path: builtins.readFile (repo + "/${path}")) entry.generatorSources
    );
  fromFile = path: typed (builtins.fromJSON (builtins.readFile path));
  fromGenerated =
    name:
    let
      entry = registry.${name};
      sourceRevision = inputs.${entry.input}.rev;
      hash = generatorHash entry;
      root = inputs.schema-artifacts + "/${name}";
      recorded = field: lib.removeSuffix "\n" (builtins.readFile (root + "/${field}"));
    in
    assert lib.assertMsg (recorded "source-revision" == sourceRevision)
      "${name} schema does not match its locked upstream revision; run system-update to refresh schemas";
    assert lib.assertMsg (
      recorded "generator-hash" == hash
    ) "${name} schema generator changed; run system-update to refresh schemas";
    fromFile (root + "/schema.json");
in
{
  inherit fromFile fromGenerated registry;
  configarr = fromGenerated "configarr";
}
