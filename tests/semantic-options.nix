{ configurations, inputs }:

let
  inherit (inputs.nixpkgs) lib;
  semanticScopeOptions = import ../modules/options/semantic-scopes.nix { inherit lib; };

  hosts = builtins.attrValues configurations;
  runtimeScopeOption = (builtins.head hosts).options.dotfiles.scopes;
  tree = semanticScopeOptions.scopeTree configurations;
  options = semanticScopeOptions.nixdOptions configurations;
  hostOptions = semanticScopeOptions.nixdHostOptions configurations (builtins.head hosts);
  nixosHostOptions = semanticScopeOptions.nixdHostOptions configurations configurations.nixos;
  serverHostOptions = semanticScopeOptions.nixdHostOptions configurations configurations.nixos-server;
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

  rootOptions = visibleOptions scopes;
  hostScopes = hostOptions.dotfiles.scopes.type.getSubOptions [ ];
  nixosHostScopes = visibleOptions (nixosHostOptions.dotfiles.scopes.type.getSubOptions [ ]);
  serverHostScopes = visibleOptions (serverHostOptions.dotfiles.scopes.type.getSubOptions [ ]);
  nixosResolvedScopes = semanticChildren configurations.nixos.config.dotfiles.resolvedScopes;
  serverResolvedScopes = semanticChildren configurations.nixos-server.config.dotfiles.resolvedScopes;
  rootChildren = semanticChildren tree;
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
assert rootChildren != { };
assert sameNames (builtins.attrNames rootChildren) (builtins.attrNames rootOptions);
assert sameNames (builtins.attrNames (
  semanticChildren (builtins.head hosts).config.dotfiles.resolvedScopes
)) (builtins.attrNames (visibleOptions hostScopes));
assert sameNames (builtins.attrNames nixosResolvedScopes) (builtins.attrNames nixosHostScopes);
assert sameNames (builtins.attrNames serverResolvedScopes) (builtins.attrNames serverHostScopes);
assert builtins.all (name: validateScope nixosResolvedScopes.${name} nixosHostScopes.${name}) (
  builtins.attrNames nixosResolvedScopes
);
assert builtins.all (name: validateScope serverResolvedScopes.${name} serverHostScopes.${name}) (
  builtins.attrNames serverResolvedScopes
);
assert !(nixosHostScopes ? serverApps);
assert serverHostScopes ? serverApps;
assert builtins.all (name: builtins.hasAttr name hostOptions) (
  builtins.attrNames (builtins.head hosts).options
);
assert builtins.all (name: validateScope rootChildren.${name} rootOptions.${name}) (
  builtins.attrNames rootChildren
);
true
