{ lib }:

let
  inherit (lib) mkOption types;

  childDefaultType = types.submodule (_: {
    options.enable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = "Optional default enable state for immediate child semantic scopes.";
    };
  });

  enableOption = {
    type = types.nullOr types.bool;
    default = null;
    description = "Optional enable override for this semantic scope.";
  };

  childrenOption = {
    type = childDefaultType;
    default = { };
    description = "Defaults applied to immediate child semantic scopes.";
  };

  scopeControlOptions =
    hasChildren:
    {
      enable = mkOption enableOption;
    }
    // lib.optionalAttrs hasChildren {
      children = mkOption childrenOption;
    };

  scopeControlNames = builtins.attrNames (scopeControlOptions true);

  resolvedScopeOptions = {
    enable = mkOption {
      type = types.bool;
      internal = true;
    };

    scopeOptions = mkOption {
      type = types.raw;
      default = { };
      internal = true;
    };
  };

  resolvedScopeControlNames = builtins.attrNames resolvedScopeOptions;

  scopeOverrideType =
    (types.submodule (_: {
      freeformType = types.attrsOf scopeOverrideType;
      options = scopeControlOptions true;
    }))
    // {
      description = "semantic scope override";
    };

  resolvedScopeType =
    (types.submodule (_: {
      freeformType = types.attrsOf resolvedScopeType;
      options = resolvedScopeOptions;
    }))
    // {
      description = "resolved semantic scope state";
    };

  semanticChildren =
    tree:
    lib.filterAttrs (
      name: value: builtins.isAttrs value && !(builtins.elem name resolvedScopeControlNames)
    ) tree;

  nixdScopeType =
    tree:
    let
      childScopes = semanticChildren tree;
    in
    types.submodule (_: {
      options =
        scopeControlOptions (childScopes != { })
        // builtins.mapAttrs (
          name: child:
          mkOption {
            type = nixdScopeType child;
            default = { };
            description = "Overrides for the ${name} semantic scope.";
          }
        ) childScopes;
    });

  scopeTree =
    configurations:
    lib.foldl' lib.recursiveUpdate { } (
      builtins.attrValues (
        builtins.mapAttrs (_: host: host.config.dotfiles.resolvedScopes) configurations
      )
    );

  nixdOptionsForTree =
    tree:
    let
      childScopes = semanticChildren tree;
    in
    if childScopes == { } then
      throw "Cannot generate semantic scope options without semantic scopes"
    else
      (lib.evalModules {
        modules = [
          {
            options.dotfiles.scopes = mkOption {
              type = types.submodule (_: {
                options = builtins.mapAttrs (
                  name: scope:
                  mkOption {
                    type = nixdScopeType scope;
                    default = { };
                    description = "Overrides for the ${name} semantic scope.";
                  }
                ) childScopes;
              });
              default = { };
              description = "Host-specific enable overrides mirroring the semantic scope tree.";
            };
          }
        ];
      }).options;

  nixdOptions = configurations: nixdOptionsForTree (scopeTree configurations);

  nixdEditOptionsForTree =
    tree:
    let
      childOptions = builtins.mapAttrs (_: nixdEditOptionsForTree) (semanticChildren tree);
      nonEmptyChildren = lib.filterAttrs (_: value: builtins.attrNames value != [ ]) childOptions;
    in
    (tree.scopeOptions or { }) // nonEmptyChildren;

  nixdHostOptions =
    _configurations: host:
    let
      resolved = host.config.dotfiles.resolvedScopes;
      # nixd drops the outer `name = editScope ...` binding when completing the edit attrset.
      editOptions = lib.foldl' lib.recursiveUpdate { } (
        lib.mapAttrsToList (_: nixdEditOptionsForTree) (semanticChildren resolved)
      );
    in
    lib.recursiveUpdate (lib.recursiveUpdate host.options (nixdOptionsForTree resolved)) editOptions;
in
{
  inherit
    nixdHostOptions
    nixdOptions
    resolvedScopeControlNames
    resolvedScopeType
    scopeControlNames
    scopeOverrideType
    scopeTree
    ;
}
