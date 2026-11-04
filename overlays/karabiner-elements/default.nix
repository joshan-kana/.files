{
  inputs,
  lib,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin;

  # Karabiner 15+ replaced the launchd services managed by nix-darwin with
  # signed SMAppService components installed by the vendor's package.
  serviceModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.karabiner-elements;
    in
    {
      disabledModules = [ "${inputs.nix-darwin}/modules/services/karabiner-elements" ];

      options.services.karabiner-elements = {
        enable = lib.mkEnableOption "Karabiner-Elements";
        package = lib.mkPackageOption pkgs "karabiner-elements" { };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ cfg.package ];

        system.activationScripts.postActivation.text = lib.mkAfter ''
          state=/var/db/.files/karabiner-elements
          installedVersion=$(/usr/sbin/pkgutil --pkg-info org.pqrs.Karabiner-Elements 2>/dev/null | /usr/bin/awk '/^version:/ { print $2 }' || true)
          if [[ ! -f "$state" ]] ||
             [[ "$(/bin/cat "$state")" != "${cfg.package}" ]] ||
             [[ "$installedVersion" != "${cfg.package.version}" ]] ||
             [[ ! -d /Applications/Karabiner-Elements.app ]] ||
             [[ ! -x "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" ]]; then
            if [[ -v DRY_RUN ]]; then
              echo "Would install Karabiner-Elements ${cfg.package.version}"
            else
              /usr/sbin/installer -pkg "${cfg.package}/share/karabiner-elements/Karabiner-Elements.pkg" -target /
              /bin/mkdir -p /var/db/.files
              /usr/bin/printf '%s\n' "${cfg.package}" > "$state"
            fi
          fi
        '';
      };
    };

in
{
  imports = lib.optionals isDarwin [ serviceModule ];

  nixpkgs.overlays = [
    (
      _final: prev:
      let
        version = "16.3.0";
        hash = "sha256-GcznvtPUinIiQspoO9G65Aa2qH/tUgco0ckd7hdbdeQ=";
      in
      prev.lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
        karabiner-elements = prev.stdenvNoCC.mkDerivation {
          pname = "karabiner-elements";
          inherit version;
          src = prev.fetchurl {
            url = "https://github.com/pqrs-org/Karabiner-Elements/releases/download/v${version}/Karabiner-Elements-${version}.dmg";
            inherit hash;
          };
          nativeBuildInputs = [ prev.undmg ];
          sourceRoot = ".";
          dontBuild = true;
          dontFixup = true;
          installPhase = ''
            runHook preInstall
            install -Dm444 Karabiner-Elements.pkg "$out/share/karabiner-elements/Karabiner-Elements.pkg"
            mkdir -p "$out/bin"
            cat > "$out/bin/karabiner_cli" <<'SH'
            #!/bin/sh
            if [ -x "/Applications/Karabiner-Elements.app/Contents/Helpers/karabiner_cli" ]; then
              exec "/Applications/Karabiner-Elements.app/Contents/Helpers/karabiner_cli" "$@"
            fi
            exec "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" "$@"
            SH
            chmod +x "$out/bin/karabiner_cli"
            runHook postInstall
          '';
          passthru = {
            autoUpdate = true;
            updateFilename = "overlays/karabiner-elements/default.nix";
            updateUrl = "https://github.com/pqrs-org/Karabiner-Elements";
          };
          meta = {
            description = "Powerful keyboard customizer for macOS";
            homepage = "https://karabiner-elements.pqrs.org/";
            license = prev.lib.licenses.unlicense;
            platforms = prev.lib.platforms.darwin;
            sourceProvenance = [ prev.lib.sourceTypes.binaryNativeCode ];
            mainProgram = "karabiner_cli";
          };
        };
      }
    )
  ];
}
