{ inputs, configurations }:

let
  inherit (inputs.nixpkgs) lib;
  registry = import ../modules/theme/registry.nix {
    inherit lib;
    pkgs = null;
  };
  names = builtins.attrNames registry.variants;
  # Every palette reaches the NixOS theme output, Stylix and the Home Manager
  # desktop runtime. This catches integration drift before any host activation.
  validates =
    name:
    let
      host = configurations."nixos-arm-parallels-${name}";
      cfg = host.config;
      home = cfg.home-manager.users.joshan;
      palette = if name == "wallpaper" then null else (registry.resolve name).colors;
      runtime = lib.attrByPath [ "xdg" "configFile" "linux-desktop/runtime.json" "source" ] null home;
    in
    (palette == null || cfg.stylix.base16Scheme.palette == palette)
    && runtime != null
    && cfg.stylix.enable
    && home.stylix.targets.gtk.enable
    && home.stylix.targets.qt.enable
    && home.programs.delta.enable
    && (palette == null || home.programs.delta.options."file-style" == "#${palette.base0D}")
    && (
      palette == null || home.programs.delta.options."line-numbers-minus-style" == "#${palette.base08}"
    )
    && (
      palette == null || home.programs.delta.options."line-numbers-plus-style" == "#${palette.base0B}"
    )
    && home.programs.bat.enable
    && home.programs.bat.config.theme == "stylix"
    && home.programs.gh.enable
    && lib.hasAttrByPath [ "xdg" "configFile" "gh-dash/stylix.yml" "source" ] home;
in
assert builtins.all validates names;
true
