{ configurations, inputs }:

let
  inherit (inputs.nixpkgs) lib;
  semanticScopeOptions = import ../modules/options/semantic-scopes.nix { inherit lib; };

  hosts = builtins.attrValues configurations;
  runtimeScopeOption = (builtins.head hosts).options.dotfiles.scopes;
  tree = semanticScopeOptions.scopeTree configurations;
  options = semanticScopeOptions.nixdOptions configurations;
  hostOptions = semanticScopeOptions.nixdHostOptions configurations (builtins.head hosts);
  scopes = options.dotfiles.scopes.type.getSubOptions [ ];

  visibleOptions =
    options':
    builtins.removeAttrs options' [
      "_freeformOptions"
      "_module"
    ];

  controlOptions = visibleOptions (runtimeScopeOption.type.nestedTypes.elemType.getSubOptions [ ]);
  leafControlOptions = lib.filterAttrs (
    _: option: visibleOptions (option.type.getSubOptions [ ]) == { }
  ) controlOptions;
  semanticChildren = lib.filterAttrs (_: value: builtins.isAttrs value);

  sameNames =
    expected: actual:
    lib.subtractLists expected actual == [ ] && lib.subtractLists actual expected == [ ];

  validateScope =
    scopeTree: scopeOption:
    let
      childScopes = semanticChildren scopeTree;
      controls = if childScopes == { } then leafControlOptions else controlOptions;
      scopeOptions = visibleOptions (scopeOption.type.getSubOptions [ ]);
      expectedNames = builtins.attrNames controls ++ builtins.attrNames childScopes;
      controlTypesMatch = builtins.all (
        name:
        sameNames (builtins.attrNames (visibleOptions (controls.${name}.type.getSubOptions [ ]))) (
          builtins.attrNames (visibleOptions (scopeOptions.${name}.type.getSubOptions [ ]))
        )
      ) (builtins.attrNames controls);
    in
    sameNames expectedNames (builtins.attrNames scopeOptions)
    && controlTypesMatch
    && builtins.all (name: validateScope childScopes.${name} scopeOptions.${name}) (
      builtins.attrNames childScopes
    );

  rootOptions = visibleOptions scopes;
  hostScopes = hostOptions.dotfiles.scopes.type.getSubOptions [ ];
  rootChildren = semanticChildren tree;
in
assert hosts != [ ];
assert rootChildren != { };
assert sameNames (builtins.attrNames rootChildren) (builtins.attrNames rootOptions);
assert sameNames (builtins.attrNames rootOptions) (builtins.attrNames (visibleOptions hostScopes));
assert builtins.all (name: builtins.hasAttr name hostOptions) (
  builtins.attrNames (builtins.head hosts).options
);
assert builtins.all (name: validateScope rootChildren.${name} rootOptions.${name}) (
  builtins.attrNames rootChildren
);
true
