_:
let
  release = {
    version = "02.09.01.70";
    build = "20261103183404";
    hash = "sha256-5PQqwVQssQfLIcv5hxfeexfnNb20b9KhgknjCSnjMQ0=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        bambu-studio = import ../../lib/mac-app.nix { inherit prev; } {
          inherit release;
          pname = "bambu-studio";
          appName = "BambuStudio.app";
          homepage = "https://github.com/bambulab/BambuStudio";
          license = prev.lib.licenses.agpl3Only;
          unpacker = prev._7zz;
          passthru = {
            autoUpdate = false;
          };
          url =
            r:
            "https://github.com/bambulab/BambuStudio/releases/download/v${r.version}/Bambu_Studio_mac-v${r.version}-${r.build}.dmg";
        };
      }
      // prev.lib.optionalAttrs (system == "x86_64-linux") {
        bambu-studio = prev.appimageTools.wrapType2 {
          pname = "bambu-studio";
          inherit (release) version;
          src = prev.fetchurl {
            url = "https://github.com/bambulab/BambuStudio/releases/download/v${release.version}/BambuStudio_ubu22_v${release.version}-${release.build}.AppImage";
            hash = "sha256-4N+22v4Bgba/hjW7uaexBvAvI0P45BlJ8dFWs/NiQeU=";
          };
          passthru = {
            autoUpdate = false;
          };
          meta = {
            homepage = "https://github.com/bambulab/BambuStudio";
            license = prev.lib.licenses.agpl3Only;
            platforms = [ "x86_64-linux" ];
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
          };
        };
      }
    )
  ];
}
