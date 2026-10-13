{
  flakeRef,
  host ? null,
}:

let
  flake = builtins.getFlake flakeRef;
  bootstrapLib = flake.inputs.nixpkgs.lib;

  # Derive host targets from the flake's configuration outputs instead of
  # binding this browser to a particular host platform.
  configurationOutputs = builtins.filter (bootstrapLib.hasSuffix "Configurations") (
    builtins.attrNames flake
  );
  hostRecords = bootstrapLib.concatMap (
    outputName:
    let
      configurations = builtins.getAttr outputName flake;
    in
    if builtins.isAttrs configurations then
      map (name: { inherit name outputName; }) (builtins.attrNames configurations)
    else
      [ ]
  ) configurationOutputs;
  hosts = bootstrapLib.unique (map (record: record.name) hostRecords);

  matches = builtins.filter (record: record.name == host) hostRecords;
  selected =
    if builtins.length matches == 1 then
      builtins.head matches
    else if matches == [ ] then
      throw "Unknown configuration host: ${toString host}"
    else
      throw "Host ${host} appears in more than one configuration output";
  system = builtins.getAttr host (builtins.getAttr selected.outputName flake);
  lib = if system ? pkgs && system.pkgs ? lib then system.pkgs.lib else bootstrapLib;
  systemScope = lib.removeSuffix "Configurations" selected.outputName;
  systemLabel =
    if systemScope == "nixos" then
      "NixOS"
    else
      lib.toUpper (builtins.substring 0 1 systemScope)
      + builtins.substring 1 (builtins.stringLength systemScope) systemScope;

  inputRoots =
    prefix: inputs:
    lib.concatMap (
      name:
      let
        input = builtins.getAttr name inputs;
        label = lib.concatStringsSep "/" (prefix ++ [ name ]);
        root = lib.optional (builtins.isAttrs input && input ? outPath) {
          inherit label;
          path = builtins.toString input.outPath;
        };
        nested =
          if builtins.isAttrs input && input ? inputs && builtins.isAttrs input.inputs then
            inputRoots (prefix ++ [ name ]) input.inputs
          else
            [ ];
      in
      root ++ nested
    ) (builtins.attrNames inputs);

  sourceRoots = [
    {
      name = "local";
      path = builtins.toString flake.outPath;
    }
  ]
  ++ builtins.map (root: {
    name = root.label;
    inherit (root) path;
  }) (inputRoots [ ] flake.inputs);

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
    hosts
    ;

  scopes = {
    ${systemScope} = {
      kind = systemScope;
      label = systemLabel;
      user = null;
      inherit (system) options config;
    };
  }
  // homeManagerScopes;
}
