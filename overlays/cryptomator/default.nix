_:
let
  release = {
    version = "1.19.7";
    hash = "sha256-xIGNOMs/mRm/4nbIEnFFlsxQ2k0BqCrC8ivy5ktEFnc=";
  };
  linuxHashes = {
    x86_64-linux = "sha256-fwNn2Lg/zaZlAW4akHaDqQN+YVifJJPEIG6oUNVf704=";
    aarch64-linux = "sha256-kqmi1GGyJ+ep4JoVVjD7NndqudqeeAsOw8BhtaV6UTk=";
  };
in
{
  nixpkgs.overlays = [
    (
      _final: prev:
      let
        pname = "cryptomator";
        homepage = "https://cryptomator.org";
        license = prev.lib.licenses.gpl3Only;
        system = prev.stdenv.hostPlatform.system;
        update = {
          autoUpdate = true;
          updateGroup = pname;
          updateUrl = "https://github.com/cryptomator/cryptomator";
          updateGithubReleases = true;
          updateFilename = "overlays/cryptomator/default.nix";
        };
      in
      prev.lib.optionalAttrs (prev.stdenv.hostPlatform.isDarwin || builtins.hasAttr system linuxHashes) {
        cryptomator =
          if prev.stdenv.hostPlatform.isDarwin then
            import ../../lib/mac-app.nix { inherit prev; } {
              inherit release;
              inherit pname;
              appName = "Cryptomator.app";
              inherit homepage license;
              passthru = update;
              url =
                r:
                "https://github.com/cryptomator/cryptomator/releases/download/${r.version}/Cryptomator-${r.version}-arm64.dmg";
            }
          else
            prev.appimageTools.wrapType2 {
              inherit pname;
              inherit (release) version;
              src = prev.fetchurl {
                url = "https://github.com/cryptomator/cryptomator/releases/download/${release.version}/cryptomator-${release.version}-${
                  if system == "aarch64-linux" then "aarch64" else "x86_64"
                }.AppImage";
                hash = linuxHashes.${system};
              };
              passthru = update;
              meta = {
                inherit homepage license;
                platforms = [
                  "x86_64-linux"
                  "aarch64-linux"
                ];
                mainProgram = "cryptomator";
                sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
              };
            };
      }
    )
  ];
}
