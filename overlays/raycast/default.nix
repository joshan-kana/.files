_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        raycast = import ../../lib/mac-app.nix { inherit prev; } {
          release = {
            version = "2.11.1.0";
            hash = "sha256-d34/vgje5B2IY5zLSccIk8Yfhfkttt3Jroaaj6ZTV1o=";
          };
          pname = "raycast";
          appName = "Raycast.app";
          homepage = "https://raycast.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          cask = "raycast";
          passthru = {
            autoUpdate = true;
            updateFilename = "overlays/raycast/default.nix";
          };
          url =
            r: "https://x.raycast-releases.com/download?platform=macos&architecture=arm64&version=${r.version}";
        };
      }
    )
  ];
}
