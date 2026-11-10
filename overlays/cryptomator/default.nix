_:
let
  release = {
    version = "1.19.6";
    hash = "sha256-/fyO9QsQusoQeLep7fQE4zA2PIo6QP2in4bdXToKCwI=";
  };
  linuxHashes = {
    x86_64-linux = "sha256-phZ/arPF8WGzFya5S88KvLf3jIV7FuSFreuOUJa3Ss0=";
    aarch64-linux = "sha256-K8E7losyxdOrXUUIeruatO8BtVhFYMF1EclWxMaB+C4=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        update = {
          autoUpdate = true;
          updateGroup = "cryptomator";
          updateUrl = "https://github.com/cryptomator/cryptomator";
          updateGithubReleases = true;
          updateFilename = "overlays/cryptomator/default.nix";
        };
      in
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin || builtins.hasAttr system linuxHashes) {
        cryptomator =
          if prev.stdenv.hostPlatform.isDarwin then
            import ../../lib/mac-app.nix { inherit prev; } {
              inherit release;
              pname = "cryptomator";
              appName = "Cryptomator.app";
              homepage = "https://cryptomator.org";
              license = prev.lib.licenses.gpl3Only;
              passthru = update;
              url =
                r:
                "https://github.com/cryptomator/cryptomator/releases/download/${r.version}/Cryptomator-${r.version}-arm64.dmg";
            }
          else
            prev.appimageTools.wrapType2 {
              pname = "cryptomator";
              inherit (release) version;
              src = prev.fetchurl {
                url = "https://github.com/cryptomator/cryptomator/releases/download/${release.version}/cryptomator-${release.version}-${
                  if system == "aarch64-linux" then "aarch64" else "x86_64"
                }.AppImage";
                hash = linuxHashes.${system};
              };
              passthru = update;
              meta = {
                homepage = "https://cryptomator.org";
                license = prev.lib.licenses.gpl3Only;
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                mainProgram = "cryptomator";
                sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
              };
            };
      }
    )
  ];
}
