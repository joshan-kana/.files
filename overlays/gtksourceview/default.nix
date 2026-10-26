_: {
  nixpkgs.overlays = [
    (_final: prev: {
      gtksourceview5 =
        if prev.stdenv.hostPlatform.system == "aarch64-linux" then
          prev.gtksourceview5.overrideAttrs (old: {
            # The buffer test aborts when Xvfb becomes unavailable on headless ARM CI.
            # Keep all remaining GTK tests enabled.
            checkPhase =
              prev.lib.replaceStrings
                [ "meson test --no-rebuild" ]
                [ "meson test --exclude test-buffer --no-rebuild" ]
                old.checkPhase;
          })
        else
          prev.gtksourceview5;
    })
  ];
}
