{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        # Remove once nixpkgs includes NixOS/nixpkgs@f985be327fad.
        open-webui = prev.open-webui.overrideAttrs {
          makeWrapperArgs = [
            "--set"
            "FRONTEND_BUILD_DIR"
            "${prev.open-webui.frontend}/share/open-webui"
          ];
        };
      }
      // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        open-webui-mac =
          import ../lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "open-webui";
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
