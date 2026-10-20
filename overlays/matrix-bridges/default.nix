{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      final: _prev:
      let
        system = final.stdenv.hostPlatform.system;
        # Keep the deprecated libolm exception limited to these bridge packages.
        upstream = import inputs.nixpkgs {
          inherit system;
          config.permittedInsecurePackages = [ "olm-3.2.16" ];
        };
      in
      {
        matrix-bridge-packages = {
          inherit (upstream)
            beeper-bridge-manager
            mautrix-whatsapp
            mautrix-signal
            mautrix-discord
            mautrix-meta
            ;
          mautrix-telegram = inputs.mautrix-packages.packages.${system}.mautrix-telegram;
        };
      }
    )
  ];
}
