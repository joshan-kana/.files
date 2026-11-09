{
  nixpkgs.overlays = [
    (_final: prev: {
      contour = prev.contour.overrideAttrs (old: {
        version = "0.8.0.9335";
        src = prev.fetchFromGitHub {
          owner = "contour-terminal";
          repo = "contour";
          tag = "v0.8.0.9335";
          hash = "sha256-WIBAIzHskEoxijHIIGm+NQ0jfvbnwyES1tiTfnetTxs=";
        };
        patches = (old.patches or [ ]) ++ [
          ./hide-active-pane-border.patch
          ./preserve-highlighted-ligatures.patch
        ];
        passthru = (old.passthru or { }) // {
          autoUpdate = false;
        };
      });
    })
  ];

  home-manager.sharedModules = [
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        options.programs.contour = {
          enable = lib.mkEnableOption "Contour terminal emulator";

          package = lib.mkPackageOption pkgs "contour" { };

          settings = lib.mkOption {
            inherit ((pkgs.formats.yaml { })) type;
            default = { };
            description = "Contour settings written to contour.yml.";
          };
        };

        config = lib.mkIf config.programs.contour.enable {
          home.packages = [
            config.programs.contour.package
            config.programs.contour.package.terminfo
          ];

          xdg.configFile."contour/contour.yml".source =
            (pkgs.formats.yaml { }).generate "contour.yml"
              config.programs.contour.settings;

          programs.contour.settings.input_mapping = lib.mkBefore (
            builtins.fromJSON (builtins.readFile ./bindings.json)
          );
        };
      }
    )
  ];
}
