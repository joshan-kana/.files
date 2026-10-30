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
              token = "open-webui";
              updateDir = "open-webui-mac";
              release = {
                version = "0.0.20";
                hash = "sha256-RU/ukQyHIWi3X5i/Z2r00Vsh38xrQ6Jt+tyUvZ7xC5c=";
              };
              pname = "open-webui-mac";
              appName = "Open WebUI.app";
              homepage = "https://openwebui.com/";
              license = prev.lib.licenses.mit;
              url =
                r: "https://github.com/open-webui/desktop/releases/download/v${r.version}/open-webui-arm64.dmg";
            };
      }
    )
  ];
}
