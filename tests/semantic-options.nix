{ configurations, inputs }:

let
  inherit (inputs.nixpkgs) lib;
  semanticScopeOptions = import ../modules/options/semantic-scopes.nix { inherit lib; };

  hosts = builtins.attrValues configurations;
  runtimeScopeOption = (builtins.head hosts).options.dotfiles.scopes;
  tree = semanticScopeOptions.scopeTree configurations;
  options = semanticScopeOptions.nixdOptions configurations;
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
  semanticChildren =
    tree:
    lib.filterAttrs (
      name: value:
      builtins.isAttrs value && !(builtins.elem name semanticScopeOptions.resolvedScopeControlNames)
    ) tree;

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

  validateEdits =
    scopeTree: editOptions:
    let
      children = semanticChildren scopeTree;
    in
    sameNames (
      [
        "config"
        "home"
      ]
      ++ builtins.attrNames children
    ) (builtins.attrNames editOptions)
    && editOptions.config.type.name == "raw"
    && editOptions.home.type.name == "raw"
    && builtins.all (name: validateEdits children.${name} editOptions.${name}) (
      builtins.attrNames children
    );

  rootOptions = visibleOptions scopes;
  rootChildren = semanticChildren tree;
  validateHost =
    host:
    let
      hostOptions = semanticScopeOptions.nixdHostOptions configurations host;
      hostScopes = visibleOptions (hostOptions.dotfiles.scopes.type.getSubOptions [ ]);
      resolved = semanticChildren host.config.dotfiles.resolvedScopes;
    in
    sameNames (builtins.attrNames resolved) (builtins.attrNames hostScopes)
    && sameNames (builtins.attrNames rootChildren) (builtins.attrNames hostOptions.scopeEdits)
    && builtins.all (name: validateScope resolved.${name} hostScopes.${name}) (
      builtins.attrNames resolved
    )
    && builtins.all (name: validateEdits rootChildren.${name} hostOptions.scopeEdits.${name}) (
      builtins.attrNames rootChildren
    )
    && builtins.all (name: builtins.hasAttr name hostOptions) (builtins.attrNames host.options);
  privateHost = {
    options = { };
    config.dotfiles.resolvedScopes.root = {
      enable = true;
      scopeOptions = { };
      app = {
        enable = true;
        scopeOptions.token = lib.mkOption {
          type = lib.types.str;
        };
      };
    };
  };
  privateHostOptions = semanticScopeOptions.nixdHostOptions { } privateHost;
in
assert hosts != [ ];
assert privateHostOptions.app.token.type.name == "str";
assert builtins.hasAttr "root" privateHostOptions.scopeEdits;
assert builtins.hasAttr "app" privateHostOptions.scopeEdits.root;
assert privateHostOptions.scopeEdits.root.app.home.type.name == "raw";
assert privateHostOptions.scopeEdits.root.app.config.type.name == "raw";
assert rootChildren != { };
assert sameNames (builtins.attrNames rootChildren) (builtins.attrNames rootOptions);
assert builtins.all validateHost hosts;
assert builtins.all (name: validateScope rootChildren.${name} rootOptions.${name}) (
  builtins.attrNames rootChildren
);
true
