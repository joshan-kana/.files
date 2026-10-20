{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        configarr =
          (prev.callPackage "${inputs.configarr}/pkgs/nix/package.nix" {
            src = inputs.configarr;
          }).overrideAttrs
            (old: {
              # Configarr v1.35.0's published hash does not match our nixpkgs pnpm fetcher.
              pnpmDeps = final.fetchPnpmDeps {
                inherit (old) pname src version;
                fetcherVersion = 4;
                hash = "sha256-LFHYsZx7xkM7mqL++Kxb6yDz/WdVyGLUDdpc2HFHzeI=";
              };
            });
      }
    )
  ];
}
