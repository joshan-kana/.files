{
  inputs,
  prev,
}:
{
  token,
  pname,
  url,
  appName,
  homepage,
  license,
  unpacker ? prev.undmg,
}:
let
  release = import ./cask.nix {
    inherit inputs token;
    inherit (prev) lib;
  };
in
prev.stdenvNoCC.mkDerivation {
  inherit pname;
  inherit (release) version;
  src = prev.fetchurl {
    url = url release;
    inherit (release) hash;
  };
  nativeBuildInputs = [ unpacker ];
  sourceRoot = ".";
  dontBuild = true;
  # Leave the signed bundle unchanged.
  dontFixup = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    app="$(find . -type d -name '${appName}' -print -quit)"
    test -n "$app"
    cp -R "$app" "$out/Applications/"
    runHook postInstall
  '';
  meta = {
    inherit homepage license;
    platforms = prev.lib.platforms.darwin;
    sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
  };
}
