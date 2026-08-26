{ lib }:

let
  nativePrefixes = [
    [ "services" ]
    [ "programs" ]
    [ "virtualisation" ]
    [ "networking" ]
    [ "hardware" ]
    [ "security" ]
    [ "xdg" ]
    [
      "wayland"
      "windowManager"
    ]
    [
      "xsession"
      "windowManager"
    ]
  ];

  commonArgs = {
    system = {
      config = false;
      inputs = false;
      modulesPath = false;
      pkgs = false;
    };
    home = {
      config = false;
      darwinConfig = false;
      modulesPath = false;
      osConfig = false;
      pkgs = false;
    };
  };

  moduleKeys = [
    "_file"
    "config"
    "disabledModules"
    "imports"
    "options"
  ];

  callScope =
    scopeModule: args:
    let
      expected = lib.functionArgs scopeModule;
    in
    scopeModule (lib.filterAttrs (name: _: builtins.hasAttr name expected) args);

  scopeOverride =
    context: path: args:
    let
      systemConfig = if context == "system" then args.config else args.osConfig or { };
    in
    if path == [ ] || !(systemConfig ? dotfiles.scopes) then
      null
    else
      lib.attrByPath (path ++ [ "enable" ]) null systemConfig.dotfiles.scopes;

  scopeConfig =
    context: parentEnabled: path: scopeModule: args:
    let
      scope = callScope scopeModule args;
      configuredEnable = scopeOverride context path args;
      ownEnabled = if configuredEnable != null then configuredEnable else (scope.enable or true);
      enabled = parentEnabled && ownEnabled;
      name = if path == [ ] then null else lib.last path;
      hasHomeContext =
        context == "system" && builtins.hasAttr "home" scope && builtins.isFunction scope.home;
      candidates = builtins.removeAttrs scope (
        moduleKeys ++ [ "enable" ] ++ lib.optional hasHomeContext "home"
      );
      children = lib.filterAttrs (_: value: builtins.isFunction value) candidates;
      directConfig = builtins.removeAttrs scope (
        [ "enable" ] ++ builtins.attrNames children ++ moduleKeys ++ lib.optional hasHomeContext "home"
      );
      nativeMatches =
        if name == null then
          [ ]
        else
          builtins.filter (
            prefix:
            let
              modulePath = prefix ++ [ name ];
            in
            lib.hasAttrByPath modulePath directConfig
            && lib.hasAttrByPath (modulePath ++ [ "enable" ]) args.options
          ) nativePrefixes;
      nativeEnable =
        if builtins.length nativeMatches == 1 then
          lib.setAttrByPath (
            (builtins.head nativeMatches)
            ++ [
              name
              "enable"
            ]
          ) (lib.mkDefault true)
        else
          { };
      homeConfig =
        lib.optionalAttrs
          (
            hasHomeContext
            && builtins.hasAttr "home-manager" args.options
            && builtins.hasAttr "sharedModules" args.options.home-manager
          )
          {
            home-manager.sharedModules = [ (mkScopeModule "home" enabled path scope.home) ];
          };
      childConfigs = lib.mapAttrsToList (
        childName: child: scopeConfig context enabled (path ++ [ childName ]) child args
      ) children;
      stateConfig =
        lib.optionalAttrs
          (
            context == "system" && path != [ ] && lib.hasAttrByPath [ "dotfiles" "resolvedScopes" ] args.options
          )
          {
            dotfiles.resolvedScopes = lib.setAttrByPath (path ++ [ "enable" ]) enabled;
          };
    in
    lib.mkMerge (
      [
        stateConfig
        (lib.mkIf enabled (
          lib.mkMerge [
            (scope.config or { })
            nativeEnable
            directConfig
            homeConfig
          ]
        ))
      ]
      ++ childConfigs
    );

  mkScopeModule =
    context: parentEnabled: path: scopeModule:
    let
      expected = lib.functionArgs scopeModule;
      wrapperArgs =
        expected
        // commonArgs.${context}
        // {
          lib = false;
          options = false;
        };
      wrapper =
        args:
        let
          scope = callScope scopeModule args;
        in
        {
          imports = scope.imports or [ ];
          options = scope.options or { };
          disabledModules = scope.disabledModules or [ ];
          config = scopeConfig context parentEnabled path scopeModule args;
        }
        // lib.optionalAttrs (scope ? _file) { inherit (scope) _file; };
    in
    lib.setFunctionArgs wrapper wrapperArgs;
in
rec {
  rootModule = scope: mkScopeModule "system" true [ ] scope;
  systemModule = name: scope: mkScopeModule "system" true [ name ] scope;
  homeModule = name: scope: mkScopeModule "home" true [ name ] scope;
  systemModules = scopes: { imports = builtins.attrValues (builtins.mapAttrs systemModule scopes); };
  homeModules = scopes: { imports = builtins.attrValues (builtins.mapAttrs homeModule scopes); };
}
