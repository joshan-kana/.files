_: {
  nixpkgs.overlays = [
    (_final: prev: {
      bottles =
        if prev.stdenv.hostPlatform.isx86 then
          prev.bottles
        else
          prev.bottles.override {
            bottles-unwrapped = prev.bottles-unwrapped.override {
              umu-launcher = prev.umu-launcher-unwrapped;
            };
          };
    })
  ];
}
