_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs (builtins.elem prev.stdenv.hostPlatform.system [ "aarch64-darwin" ]) {
        raycast = import ../../lib/cask-app.nix { inherit prev; } {
          cask = "raycast";
          release = {
            version = "2.11.1.0";
            hash = "sha256-d34/vgje5B2IY5zLSccIk8Yfhfkttt3Jroaaj6ZTV1o=";
          };
          pname = "raycast";
          appName = "Raycast.app";
          homepage = "https://raycast.com";
          license = prev.lib.licenses.unfree;
          unpacker = prev._7zz;
          url =
            r: "https://x.raycast-releases.com/download?platform=macos&architecture=arm64&version=${r.version}";
        };
      }
    )
  ];
}
