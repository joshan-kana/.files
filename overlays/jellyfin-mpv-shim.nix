_: {
  nixpkgs.overlays = [
    (
      _final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        jellyfin-mpv-shim = prev.jellyfin-mpv-shim.overridePythonAttrs (old: {
          nativeBuildInputs = prev.lib.filter (
            pkg:
            !(builtins.elem (prev.lib.getName pkg) [
              "wrap-gapps-hook"
              "gobject-introspection-wrapped"
            ])
          ) (old.nativeBuildInputs or [ ]);
          preFixup = "";
          meta = old.meta // {
            platforms = prev.lib.platforms.darwin;
          };
        });
      }
    )
  ];
}
