{ prev }:
{
  pname,
  release,
  url,
  appName,
  homepage,
  license,
  unpacker ? prev.undmg,
  unpackCmd ? null,
  passthru ? { },
}:
prev.stdenvNoCC.mkDerivation (
  {
    inherit pname passthru;
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
      mkdir -p "$out/bin"
      printf '#!/bin/sh\nexec /usr/bin/open -a "%s/Applications/${appName}" --args "$@"\n' "$out" > "$out/bin/${pname}"
      chmod +x "$out/bin/${pname}"
      runHook postInstall
    '';
    meta = {
      inherit homepage license;
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
    };
  }
  // prev.lib.optionalAttrs (unpackCmd != null) { inherit unpackCmd; }
)
