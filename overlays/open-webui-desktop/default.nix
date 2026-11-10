_:
let
  release = {
    version = "0.1.4";
    hash = "sha256-kSZQE0Vcxpn5StxNj5EWfKQRp3D/iOHgeSwZtQwrSvM=";
  };
  linuxHashes = {
    x86_64-linux = "sha256-roZeJRV5GDsb9jhaOgeFXtBtmiRF5YRTeIFD2l1h+ag=";
    aarch64-linux = "sha256-shYrE1dr9PInvF+DEXLJKueWisCI0q6o+uS5F3s7ZJQ=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        system = prev.stdenv.hostPlatform.system;
        passthru = {
          autoUpdate = true;
          updateGroup = "open-webui-desktop";
          updateUrl = "https://github.com/open-webui/desktop";
          updateGithubReleases = true;
          updateFilename = "overlays/open-webui-desktop/default.nix";
        };
      in
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin || builtins.hasAttr system linuxHashes) {
        open-webui-desktop =
          if prev.stdenv.hostPlatform.isDarwin then
            import ../../lib/mac-app.nix { inherit prev; } {
              inherit release passthru;
              pname = "open-webui-desktop";
              appName = "Open WebUI.app";
              homepage = "https://openwebui.com/";
              license = prev.lib.licenses.mit;
              url =
                r: "https://github.com/open-webui/desktop/releases/download/v${r.version}/open-webui-arm64.dmg";
            }
          else
            prev.appimageTools.wrapType2 {
              pname = "open-webui-desktop";
              inherit (release) version;
              src = prev.fetchurl {
                url = "https://github.com/open-webui/desktop/releases/download/v${release.version}/open-webui_${
                  if system == "aarch64-linux" then "arm64" else "x86_64"
                }.AppImage";
                hash = linuxHashes.${system};
              };
              inherit passthru;
              meta = {
                homepage = "https://openwebui.com/";
                license = prev.lib.licenses.mit;
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                mainProgram = "open-webui-desktop";
                sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
              };
            };
      }
    )
  ];
}
