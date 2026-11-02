{ inputs, system }:
let
  upstream = inputs.configarr.inputs.nixpkgs.legacyPackages.${system};
  overlay =
    builtins.head
      (import ../../overlays/configarr {
        config = { };
        inherit inputs system;
        inherit (upstream) lib;
        pkgs = upstream;
      }).config.nixpkgs.overlays;
  package = (overlay upstream upstream).configarr;
in
upstream.stdenvNoCC.mkDerivation {
  pname = "configarr-json-schema";
  inherit (package) version;
  src = inputs.configarr;
  inherit (package) pnpmDeps;
  nativeBuildInputs = with upstream; [
    nodejs_24
    pnpm
    pnpmConfigHook
  ];
  buildPhase = ''
    runHook preBuild
    cp ${./export-schema.ts} ./export-schema.ts
    ./node_modules/.bin/tsx ./export-schema.ts > schema.json
    runHook postBuild
  '';
  installPhase = ''
    mkdir -p $out
    cp schema.json $out/schema.json
  '';
}
