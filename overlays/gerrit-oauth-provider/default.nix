_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        gerrit-oauth-provider = prev.stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "gerrit-oauth-provider";
          version = "3.15.0";
          # Gerrit derives the installed plugin name from the store basename.
          name = "${finalAttrs.pname}.jar";
          src = prev.fetchurl {
            url = "https://github.com/davido/gerrit-oauth-provider/releases/download/v${finalAttrs.version}/oauth-github.jar";
            hash = "sha256-tMkBgD486aHnFkWvQh4SmCnVUCJpKDARNaW++4RuTII=";
          };
          # Plugin releases must be compatible with the selected Gerrit version.
          passthru = {
            autoUpdate = false;
            updateGithubReleases = true;
          };
          dontUnpack = true;
          installPhase = ''
            runHook preInstall
            cp "$src" "$out"
            runHook postInstall
          '';
          meta = {
            description = "GitHub OAuth provider plugin for Gerrit";
            homepage = "https://github.com/davido/gerrit-oauth-provider";
            platforms = prev.lib.platforms.linux;
          };
        });
      }
    )
  ];
}
