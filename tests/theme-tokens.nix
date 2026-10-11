{ inputs }:

let
  inherit (inputs.nixpkgs) lib;
  # Only the registry's pure palette data is inspected; no host or fonts need evaluation.
  registry = import ../modules/theme/registry.nix {
    inherit lib;
    pkgs = null;
  };
  static = builtins.removeAttrs registry.variants [ "wallpaper" ];
  native = import ../modules/theme/native-palettes.nix;
  uiNames = [
    "background"
    "surface"
    "surfaceRaised"
    "outline"
    "textMuted"
    "text"
    "textStrong"
    "critical"
    "warning"
    "positive"
    "accent"
    "notificationPaused"
    "reducedMotion"
  ];
  base16Names = map (n: "base0${lib.toUpper (lib.toHexString n)}") (lib.range 0 15);
  hex = value: builtins.isString value && builtins.match "[0-9a-fA-F]{6}" value != null;
  complete =
    theme:
    builtins.attrNames theme.ui == lib.sort builtins.lessThan uiNames
    && builtins.attrNames theme.colors == lib.sort builtins.lessThan base16Names
    && builtins.all hex (builtins.attrValues theme.ui ++ builtins.attrValues theme.colors);
  distinctStates =
    theme:
    let
      colors = map (role: theme.ui.${role}) [
        "accent"
        "critical"
        "warning"
        "positive"
        "notificationPaused"
        "reducedMotion"
      ];
    in
    builtins.length (lib.unique colors) == builtins.length colors;
  expected = {
    catppuccin-mocha = {
      base00 = "1e1e2e";
      base08 = "f38ba8";
      base0D = "89b4fa";
    };
    dracula = {
      base00 = "282a36";
      base08 = "ff5555";
      base0A = "f1fa8c";
    };
    gruvbox-material = {
      base00 = "292828";
      base0B = "a9b665";
      base0D = "7daea3";
    };
    kanagawa = {
      base00 = "1f1f28";
      base08 = "c34043";
      base0D = "7e9cd8";
    };
    nord = {
      base00 = "2e3440";
      base0A = "ebcb8b";
      base0D = "81a1c1";
    };
    rose-pine = {
      base00 = "191724";
      base08 = "eb6f92";
      base0D = "9ccfd8";
    };
    tokyo-night = {
      base00 = "1a1b26";
      base08 = "f7768e";
      base0A = "e0af68";
      base0D = "7aa2f7";
    };
  };
  matchesReference =
    name: values:
    builtins.all (key: native.${name}.colors.${key} == values.${key}) (builtins.attrNames values);
in
assert builtins.length (builtins.attrNames static) == 10;
assert builtins.all (name: complete (registry.resolve name)) (builtins.attrNames static);
assert builtins.all (name: distinctStates (registry.resolve name)) (builtins.attrNames static);
assert builtins.all (name: matchesReference name expected.${name}) (builtins.attrNames expected);
assert (registry.resolve "tokyo-night").ui.notificationPaused == "ff9e64";
assert (registry.resolve "tokyo-night").ui.reducedMotion == "bb9af7";
assert builtins.all (name: lib.hasPrefix "https://" native.${name}.source) (
  builtins.attrNames native
);
assert !((registry.resolve "wallpaper") ? colors);
true
