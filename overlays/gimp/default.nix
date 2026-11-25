_:
let
  release = {
    version = "3.2.8";
    hashes = {
      aarch64-darwin = "sha256-BkBKN1EGt2E7o6FMfY2afL4YubnisgULty8xYsvPw5U=";
      x86_64-linux = "sha256-i0PcI+WKG2as6d1tTV9+hTLzOY5hCflaHsC2rQNqolA=";
      aarch64-linux = "sha256-P9YdvEC3YPeAb/wEwp3A2TAht5m50OaXdXHEQl0DI7A=";
    };
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        pname = "gimp";
        homepage = "https://www.gimp.org";
        license = prev.lib.licenses.gpl3Plus;
        passthru = {
          autoUpdate = false;
          updateGroup = pname;
          updateFilename = "overlays/gimp/default.nix";
        };
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        gimp = import ../../lib/mac-app.nix { inherit prev; } {
          release = release // {
            hash = release.hashes.aarch64-darwin;
          };
          inherit pname;
          appName = "GIMP.app";
          inherit homepage license;
          unpacker = prev._7zz;
          unpackCmd = ''
            7zz x -sns- -snld20 -y "$curSrc"
          '';
          inherit passthru;
          url =
            r:
            "https://download.gimp.org/gimp/v${prev.lib.versions.majorMinor r.version}/macos/gimp-${r.version}-${
              if prev.stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64"
            }.dmg";
        };
      }
      //
        prev.lib.optionalAttrs
          (builtins.elem prev.stdenv.hostPlatform.system [
            "x86_64-linux"
            "aarch64-linux"
          ])
          {
            gimp = prev.appimageTools.wrapType2 {
              inherit pname;
              inherit (release) version;
              src = prev.fetchurl {
                url = "https://download.gimp.org/gimp/v${prev.lib.versions.majorMinor release.version}/linux/GIMP-${release.version}-${
                  if prev.stdenv.hostPlatform.isAarch64 then "aarch64" else "x86_64"
                }.AppImage";
                hash = release.hashes.${prev.stdenv.hostPlatform.system};
              };
              inherit passthru;
              meta = {
                inherit homepage license;
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
              };
            };
          }
    )
  ];
}
