{ lib, system, ... }:

{
  nixpkgs.overlays = lib.optionals (lib.systems.elaborate system).isLinux [
    (_final: prev: {
      seerr = prev.seerr.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          cp next.config.ts "$out/share/next.config.ts"
          mkdir -p "$out/share/.next/cache"
        '';
      });
    })
  ];
}
