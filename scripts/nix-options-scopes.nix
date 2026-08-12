{ flakeRef, host }:

let
  flake = builtins.getFlake flakeRef;
  system = builtins.getAttr host flake.nixosConfigurations;
  lib = if system ? pkgs && system.pkgs ? lib then system.pkgs.lib else flake.inputs.nixpkgs.lib;

  sourceRoots = [
    {
      name = "local";
      path = builtins.toString flake.outPath;
    }
  ]
  ++ lib.mapAttrsToList (name: input: {
    inherit name;
    path = builtins.toString input.outPath;
  }) (lib.filterAttrs (_: input: builtins.isAttrs input && input ? outPath) flake.inputs);

  sourcePath =
    rawFile:
    let
      file = builtins.unsafeDiscardStringContext (builtins.toString rawFile);
      matchingRoots = builtins.filter (
        root: file == root.path || lib.hasPrefix "${root.path}/" file
      ) sourceRoots;
      selectedRoot = lib.foldl' (
        best: candidate:
        if best == null || builtins.stringLength candidate.path > builtins.stringLength best.path then
          candidate
        else
          best
      ) null matchingRoots;
      relativePath =
        if selectedRoot == null then
          file
        else if file == selectedRoot.path then
          ""
        else
          lib.removePrefix "${selectedRoot.path}/" file;
    in
    {
      inherit file relativePath;
      source = if selectedRoot == null then null else selectedRoot.name;
      label =
        if selectedRoot == null then
          file
        else if relativePath == "" then
          selectedRoot.name
        else
          "${selectedRoot.name}/${relativePath}";
    };

  originPath =
    rawFile:
    let
      path = sourcePath rawFile;
      note =
        if lib.hasPrefix "<unknown" path.file then
          "generated or inline module"
        else if
          (path.source == "nixpkgs" && path.relativePath == "lib/modules.nix")
          || path.file == "lib/modules.nix"
        then
          "Nix module system"
        else if
          path.source != null
          && lib.hasPrefix "home-manager" path.source
          && path.relativePath == "modules/misc/submodule-support.nix"
        then
          "Home Manager submodule plumbing"
        else if
          path.source != null
          && lib.hasPrefix "home-manager" path.source
          && path.relativePath == "nixos/common.nix"
        then
          "Home Manager integration bridge"
        else
          null;
    in
    path
    // {
      inherit note;
      label = if note == null then path.label else "${path.label} [${note}]";
    };

  homeManagerUsersOption = lib.attrByPath [ "home-manager" "users" ] null system.options;
  homeManagerUserMetadata =
    if
      homeManagerUsersOption != null
      && homeManagerUsersOption ? valueMeta
      && homeManagerUsersOption.valueMeta ? attrs
    then
      homeManagerUsersOption.valueMeta.attrs
    else
      { };

  configuredHomeManagerUsers = lib.attrByPath [ "home-manager" "users" ] { } system.config;
  homeManagerUsers = builtins.filter (user: builtins.hasAttr user configuredHomeManagerUsers) (
    builtins.attrNames homeManagerUserMetadata
  );

  homeManagerScopes = lib.genAttrs' homeManagerUsers (
    user:
    lib.nameValuePair "home-manager:${user}" {
      kind = "home-manager";
      label = "Home Manager: ${user}";
      inherit user;
      options = homeManagerUserMetadata.${user}.configuration.options;
      config = builtins.getAttr user configuredHomeManagerUsers;
    }
  );
in
{
  inherit
    lib
    originPath
    sourcePath
    system
    ;

  scopes = {
    nixos = {
      kind = "nixos";
      label = "NixOS";
      user = null;
      inherit (system) options config;
    };
  }
  // homeManagerScopes;
}
