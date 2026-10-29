{
  prev,
}:
{
  token,
  release,
  pname,
  url,
  appName,
  homepage,
  license,
  unpacker ? prev.undmg,
  autoUpdate ? true,
}:
let
  versions = prev.lib.splitString "," release.version;
  metadata = {
    version = builtins.head versions;
    inherit versions;
  };
in
prev.stdenvNoCC.mkDerivation {
  inherit pname;
  inherit (metadata) version;
  src = prev.fetchurl {
    url = url metadata;
    inherit (release) hash;
  };
  passthru.autoUpdate = autoUpdate;
  passthru.updateScript = [
    "${prev.python3}/bin/python3"
    "${../scripts/update-cask.py}"
    token
  ];
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
