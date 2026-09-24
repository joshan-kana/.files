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
    "scopeOptions"
    "__scopeOptionOverrides"
  ];

  reservedChildNames = moduleKeys ++ [
    "enable"
    "children"
  ];

  validateScope =
    path: scope:
    let
      invalidChildren = builtins.filter (
        name: builtins.hasAttr name scope && lib.isFunction scope.${name}
      ) reservedChildNames;
      scopeName = if path == [ ] then "<root>" else lib.concatStringsSep "." path;
    in
    if invalidChildren == [ ] then
      scope
    else
      throw "Semantic scope ${scopeName} uses reserved child scope name(s): ${lib.concatStringsSep ", " invalidChildren}";

  callScope =
    scopeModule: args:
    let
      expected = lib.functionArgs scopeModule;
      supplied = lib.filterAttrs (name: _: builtins.hasAttr name expected) args;
      scope = scopeModule (
        supplied
        // lib.optionalAttrs (expected ? scopeConfig) {
          scopeConfig = args.scopeConfig or resolvedScopeConfig;
        }
      );
      rawDeclarations = scope.scopeOptions or { };
      declarations =
        if builtins.isAttrs rawDeclarations then
          rawDeclarations
        else
          throw "scopeOptions must be an attribute set of lib.mkOption declarations.";
      invalid = builtins.attrNames (lib.filterAttrs (_: option: !lib.isOption option) declarations);
      resolvedScopeConfig =
        (lib.evalModules {
          modules = [
            {
              options = declarations;
              config = scope.__scopeOptionOverrides or { };
            }
          ];
        }).config;
    in
    if invalid != [ ] then
      throw "scopeOptions entries must be lib.mkOption declarations: ${lib.concatStringsSep ", " invalid}"
    else if declarations != { } && !(expected ? scopeConfig) then
      throw "Semantic scopes declaring scopeOptions must accept the scopeConfig argument."
    else
      scope;

  hasHomeBranch = scope: builtins.hasAttr "home" scope && lib.isFunction scope.home;

  scopeForContext =
    context: projectHomeBranches: path: scope: args:
    if context == "home" && projectHomeBranches then
      if hasHomeBranch scope then validateScope path (callScope scope.home args) else { }
    else
      scope;

  scopeOverride =
    context: path: suffix: args:
    let
      osConfig = args.osConfig or null;
      hostConfig =
        if context == "system" then
          args.config
        else if builtins.isAttrs osConfig && osConfig ? dotfiles.scopes then
          osConfig
        else
          args.config;
    in
    if path == [ ] || !(hostConfig ? dotfiles.scopes) then
      null
    else
      lib.attrByPath (path ++ suffix) null hostConfig.dotfiles.scopes;

  scopeConfig =
    context: projectHomeBranches: parentEnabled: parentChildEnabled: path: scopeModule: args:
    let
      scope = validateScope path (callScope scopeModule args);
      contextScope = scopeForContext context projectHomeBranches path scope args;
      configuredEnable = scopeOverride context path [ "enable" ] args;
      ownEnabled =
        if configuredEnable != null then configuredEnable else scope.enable or parentChildEnabled;
      enabled = parentEnabled && ownEnabled;
      configuredChildEnable = scopeOverride context path [ "children" "enable" ] args;
      childEnabled = if configuredChildEnable != null then configuredChildEnable else true;
      name = if path == [ ] then null else lib.last path;
      homeBranch = hasHomeBranch scope;
      candidates = builtins.removeAttrs scope (
        moduleKeys ++ [ "enable" ] ++ lib.optional homeBranch "home"
      );
      children = lib.filterAttrs (_: value: lib.isFunction value) candidates;
      directConfig =
        if context == "home" && projectHomeBranches then
          builtins.removeAttrs contextScope ([ "enable" ] ++ moduleKeys)
        else
          builtins.removeAttrs scope (
            [ "enable" ] ++ builtins.attrNames children ++ moduleKeys ++ lib.optional homeBranch "home"
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
            context == "system"
            && homeBranch
            && builtins.hasAttr "home-manager" args.options
            && builtins.hasAttr "sharedModules" args.options.home-manager
          )
          {
            # This is already the selected Home Manager branch, so do not project again.
            home-manager.sharedModules = [
              (mkScopeModule "home" false enabled path scope.home)
            ];
          };
      childConfigs = lib.mapAttrsToList (
        childName: child:
        scopeConfig context projectHomeBranches enabled childEnabled (path ++ [ childName ]) child args
      ) children;
      stateConfig =
        lib.optionalAttrs (path != [ ] && lib.hasAttrByPath [ "dotfiles" "resolvedScopes" ] args.options)
          {
            dotfiles.resolvedScopes = lib.setAttrByPath path {
              enable = enabled;
              scopeOptions = scope.scopeOptions or { };
            };
          };
    in
    lib.mkMerge (
      [
        stateConfig
        (lib.mkIf enabled (
          lib.mkMerge [
            (contextScope.config or { })
            nativeEnable
            directConfig
            homeConfig
          ]
        ))
      ]
      ++ childConfigs
    );

  extendScope =
    scope: additions:
    let
      invalid = builtins.attrNames (lib.filterAttrs (_: value: !lib.isFunction value) additions);
    in
    if invalid != [ ] then
      throw "Semantic scope extensions must be scope functions: ${lib.concatStringsSep ", " invalid}"
    else
      lib.setFunctionArgs (
        args:
        let
          inherited = callScope scope args;
          overlap = builtins.attrNames (builtins.intersectAttrs inherited additions);
        in
        if overlap != [ ] then
          throw "Semantic scope extension already exists: ${lib.concatStringsSep ", " overlap}"
        else
          inherited // additions
      ) (lib.functionArgs scope);

  editScope =
    scope: edits:
    lib.setFunctionArgs (
      args:
      let
        inherited = callScope scope args;
        localOptions = inherited.scopeOptions or { };
        localOptionNames = builtins.attrNames localOptions;
        localEdits = lib.filterAttrs (name: _: builtins.elem name localOptionNames) edits;
        structuralEdits = builtins.removeAttrs edits localOptionNames;
      in
      inherited
      // builtins.mapAttrs (
        name: edit:
        let
          hasChild = builtins.hasAttr name inherited;
          child = inherited.${name} or null;
          isDeclaredOption =
            !hasChild && builtins.hasAttr name (args.options or { }) && lib.isOption args.options.${name};
        in
        if isDeclaredOption then
          edit
        else if !hasChild then
          throw "Unknown semantic scope edit target '${name}'."
        else if !lib.isFunction child then
          throw "Semantic scope edit target '${name}' is not a child scope or declared option."
        else if builtins.isAttrs edit then
          editScope child edit
        else if lib.isFunction edit then
          lib.setFunctionArgs
            (
              childArgs:
              let
                previous = callScope child childArgs;
              in
              lib.recursiveUpdate previous (
                callScope edit (
                  childArgs
                  // {
                    inherited = previous;
                    inherit lib;
                  }
                )
              )
            )
            (
              (lib.functionArgs child)
              // builtins.removeAttrs (lib.functionArgs edit) [
                "inherited"
                "lib"
              ]
            )
        else
          throw "Semantic scope edit '${name}' must be a nested scope set or editor function."
      ) structuralEdits
      // lib.optionalAttrs (localEdits != { }) {
        __scopeOptionOverrides = (inherited.__scopeOptionOverrides or { }) // localEdits;
      }
    ) ((lib.functionArgs scope) // { options = false; });

  mkScopeModule =
    context: projectHomeBranches: parentEnabled: path: scopeModule:
    let
      expected = lib.functionArgs scopeModule;
      wrapperArgs =
        builtins.removeAttrs expected [ "scopeConfig" ]
        // commonArgs.${context}
        // {
          lib = false;
          options = false;
        };
      wrapper =
        args:
        let
          scope = validateScope path (callScope scopeModule args);
          contextScope = scopeForContext context projectHomeBranches path scope args;
        in
        {
          imports = contextScope.imports or [ ];
          options = contextScope.options or { };
          disabledModules = contextScope.disabledModules or [ ];
          config = scopeConfig context projectHomeBranches parentEnabled true path scopeModule args;
        }
        // lib.optionalAttrs (scope ? _file) { inherit (scope) _file; };
    in
    lib.setFunctionArgs wrapper wrapperArgs;
in
rec {
  inherit
    editScope
    extendScope
    ;

  rootModule = scope: mkScopeModule "system" false true [ ] scope;
  systemModule = name: scope: mkScopeModule "system" false true [ name ] scope;
  homeModule = name: scope: mkScopeModule "home" true true [ name ] scope;
  systemModules = scopes: { imports = builtins.attrValues (builtins.mapAttrs systemModule scopes); };
  homeModules = scopes: { imports = builtins.attrValues (builtins.mapAttrs homeModule scopes); };
}
