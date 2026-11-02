_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        chatgpt-mac =
          import ../../lib/mac-app.nix
            {
              inherit prev;
            }
            {
              token = "chatgpt";
              release = {
                version = "26.1027.61615";
                hash = "sha256-oi6B/55S5/MAbGV/8gBsA0mCh2paigArv5wA+/gwfyM=";
              };
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
