_: {
  virtualisation.vmVariant.virtualisation = {
    cores = 4;
    memorySize = 8192;
  };

  aliases =
    { pkgs, ... }:
    let
      aliases = {
        sysvm = "build-vm";
        svm = "build-vm";
      };
      buildVm = pkgs.writeShellApplication {
        name = "build-vm";
        text = ''
          read -r -a rebuildFlags <<< "''${NIXOS_REBUILD_FLAGS:-}"
          sudo nixos-rebuild --flake "$DOTFILES#$FLK_PROFILE" "''${rebuildFlags[@]}" build-vm
        '';
      };
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [ buildVm ];

      home = _: {
        home.shellAliases = aliases;
        home.packages = [ buildVm ];
      };
    };
}
