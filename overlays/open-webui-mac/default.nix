_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        open-webui-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              release = {
                version = "0.1.4";
                hash = "sha256-kSZQE0Vcxpn5StxNj5EWfKQRp3D/iOHgeSwZtQwrSvM=";
              };
              pname = "open-webui-mac";
              appName = "Open WebUI.app";
              homepage = "https://openwebui.com/";
              license = prev.lib.licenses.mit;
              passthru = {
                autoUpdate = true;
                updateUrl = "https://github.com/open-webui/desktop";
                updateGithubReleases = true;
                updateFilename = "overlays/open-webui-mac/default.nix";
              };
              url =
                r: "https://github.com/open-webui/desktop/releases/download/v${r.version}/open-webui-arm64.dmg";
            };
      }
    )
  ];
}
