{ inputs, ... }: {
  home-manager.sharedModules = [ inputs.zen-browser.homeModules.beta ];

  nixpkgs.overlays = [
    (final: _prev: {
      zen-browser-beta =
        inputs.zen-browser.packages.${final.stdenv.hostPlatform.system}.beta.overrideAttrs
          (old: {
            passthru = (old.passthru or { }) // {
              autoUpdate = false;
            };
          });
    })
  ];
}
