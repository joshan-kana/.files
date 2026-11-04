_:

let
  rules = builtins.readDir ./files/complex_modifications;
in
{
  services.karabiner-elements.enable = true;

  home =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # The settings UI writes karabiner.json. Merge the declared rules into
      # a writable copy instead of linking a read-only Nix store file.
      home.activation.karabinerSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          format = "json";
          empty = "{}";
          jqOperation = "$dynamic * $static";
          path = "${config.xdg.configHome}/karabiner/karabiner.json";
          staticSettings = ./files/karabiner.json;
          mode = "600";
        }
      );

      xdg.configFile = lib.mapAttrs' (
        name: _:
        lib.nameValuePair "karabiner/assets/complex_modifications/${name}" {
          source = ./files/complex_modifications + "/${name}";
          force = true;
        }
      ) rules;
    };
}
