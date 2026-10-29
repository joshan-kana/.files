_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        # Remove once nixpkgs includes NixOS/nixpkgs#578265.
        # PostHog's MCP 2 compatibility test still uses the removed structuredContent field.
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (_pythonFinal: pythonPrev: {
            posthog =
              if pythonPrev.posthog.meta.broken or false then
                pythonPrev.posthog.overridePythonAttrs (old: {
                  disabledTests = (old.disabledTests or [ ]) ++ [
                    "test_prepare_tool_result_delivers_into_call_tool_result_models"
                  ];
                  meta = old.meta // {
                    broken = false;
                  };
                })
              else
                pythonPrev.posthog;
          })
        ];

        # Remove once nixpkgs includes NixOS/nixpkgs@f985be327fad.
        open-webui =
          (prev.open-webui.override {
            python3Packages = prev.python3Packages // {
              mcp = prev.python3Packages.mcp_1;
            };
          }).overrideAttrs
            {
              makeWrapperArgs = [
                "--set"
                "FRONTEND_BUILD_DIR"
                "${prev.open-webui.frontend}/share/open-webui"
              ];
            };
      }
      // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        open-webui-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "open-webui";
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
