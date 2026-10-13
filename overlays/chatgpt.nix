{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        chatgpt-mac =
          import ./lib/mac-app.nix
            {
              inherit prev inputs;
            }
            {
              token = "chatgpt";
              pname = "chatgpt-mac";
              appName = "ChatGPT.app";
              homepage = "https://chatgpt.com/";
              license = prev.lib.licenses.unfree;
              url = r: "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-${r.version}.zip";
              unpacker = prev.unzip;
            };
      }
    )
  ];
}
