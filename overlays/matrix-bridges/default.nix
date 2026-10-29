{ inputs, ... }: {
  nixpkgs.overlays = [
    (
      final: prev:
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux (
        let
          # Isolate the deprecated libolm exception from the rest of the package set.
          upstream = import inputs.nixpkgs {
            inherit (prev.stdenv.hostPlatform) system;
            config.permittedInsecurePackages = [ "olm-3.2.16" ];
          };
        in
        {
          mautrix-telegram-go = upstream.callPackage (
            {
              lib,
              buildGoModule,
              fetchFromGitHub,
              stdenv,
              olm,
            }:
            buildGoModule (finalAttrs: {
              pname = "mautrix-telegram";
              version = "0.2610.0";
              src = fetchFromGitHub {
                owner = "mautrix";
                repo = "telegram";
                rev = "v${finalAttrs.version}";
                hash = "sha256-2oHtqtpFhNr+v49nMSe33RGDj+MQV2D/+8JX+YYWi+0=";
              };
              vendorHash = "sha256-JbnlJnCtIKC3rpO2mBa7DvEFeWuq9tpvN9H+MoQ5VV0=";
              ldflags = [
                "-s"
                "-X main.Tag=v${finalAttrs.version}"
                "-X main.Commit=v${finalAttrs.version}"
                "-X main.BuildTime=1980-01-01T00:00:02Z"
              ];
              buildInputs = [
                stdenv.cc.cc.lib
                olm
              ];
              doCheck = false;
              passthru.autoUpdate = true;
              meta = {
                description = "Matrix-Telegram hybrid puppeting/relaybot bridge";
                homepage = "https://github.com/mautrix/telegram";
                license = lib.licenses.agpl3Plus;
                mainProgram = "mautrix-telegram";
                platforms = lib.platforms.linux;
              };
            })
          ) { };

          matrix-bridge-packages = {
            inherit (upstream)
              beeper-bridge-manager
              mautrix-whatsapp
              mautrix-signal
              mautrix-discord
              mautrix-meta
              ;
            mautrix-telegram = final.mautrix-telegram-go;
          };
        }
      )
    )
  ];
}
