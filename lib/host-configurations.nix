{
  inputs,
  lib,
  moduleRegistry,
  semantic,
}:

configurationName:
{
  system,
  hostModule,
  nixpkgsInput ? inputs.nixpkgs,
  homeManagerInput ? inputs.home-manager,
  stylixInput ? inputs.stylix,
  moduleRegistryInput ? moduleRegistry,
  configurationOutputName ? configurationName,
  configurationFlakeSubdirectory ? null,
  extraModules ? [ ],
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  hostFile =
    if builtins.pathExists (hostModule + "/default.nix") then
      hostModule + "/default.nix"
    else
      hostModule;
  hostScope = import hostFile;
  scopedHost = lib.setFunctionArgs (args: (hostScope args) // { _file = toString hostFile; }) (
    lib.functionArgs hostScope
  );

  specialArgs = {
    inherit
      configurationFlakeSubdirectory
      configurationName
      configurationOutputName
      inputs
      system
      ;
    inherit (semantic) editScope extendScope;
    moduleRegistry = moduleRegistryInput;
  };

  systemConstructor =
    if isDarwin then inputs.nix-darwin.lib.darwinSystem else nixpkgsInput.lib.nixosSystem;
in
systemConstructor {
  inherit system specialArgs;
  modules = [
    ../modules/options
    (semantic.rootModule scopedHost)
    ../overlays/comin.nix
  ]
  ++ lib.optionals isLinux [
    stylixInput.nixosModules.stylix
    homeManagerInput.nixosModules.home-manager
    ../overlays/bottles.nix
    ../overlays/gh-dash.nix
    ../overlays/libreoffice.nix
    ../overlays/nixos-options-doc.nix
    ../overlays/nvtop.nix
    ../overlays/tuicr.nix
    ../overlays/webhook.nix
  ]
  ++ lib.optionals isDarwin [
    inputs.home-manager.darwinModules.home-manager
    inputs.stylix.darwinModules.stylix
    inputs.determinate.darwinModules.default
    ../overlays/hammerspoon.nix
    ../overlays/mac-slicers.nix
    ../overlays/mac-apps.nix
  ]
  ++ extraModules;
}
