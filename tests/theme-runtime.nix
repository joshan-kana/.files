{
  inputs,
  pkgs,
  configurations,
}:

let
  inherit (inputs.nixpkgs) lib;
  registry = import ../modules/theme/registry.nix {
    inherit lib;
    pkgs = null;
  };
  names = builtins.attrNames (builtins.removeAttrs registry.variants [ "wallpaper" ]);
  check =
    name:
    let
      inherit ((registry.resolve name)) ui;
      expected = pkgs.writeText "${name}-ui-tokens.json" (
        builtins.toJSON (lib.mapAttrs (_: value: "#${value}") ui)
      );
      runtime =
        configurations."nixos-arm-parallels-${name}".config.home-manager.users.joshan.xdg.configFile."linux-desktop/runtime.json".source;
    in
    ''
      echo 'Validating ${name} Quickshell runtime tokens'
      jq -e --slurpfile expected ${expected} '.theme == $expected[0]' ${runtime} >/dev/null
    '';
in
pkgs.runCommand "theme-runtime-audit" { nativeBuildInputs = [ pkgs.jq ]; } ''
  set -euo pipefail
  ${lib.concatMapStringsSep "\n" check names}
  touch "$out"
''
