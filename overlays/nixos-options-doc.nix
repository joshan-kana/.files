{ lib, ... }:

let
  # Home Manager option docs can carry declaration paths from the nixpkgs
  # module library. Strip the nixpkgs store prefix before nixosOptionsDoc
  # serializes its context-free JSON payload.
  wrapNixosOptionsDoc =
    nixpkgsPath: upstream: args:
    let
      upstreamTransform = args.transformOptions or lib.id;
      nixpkgsPrefix = "${builtins.unsafeDiscardStringContext (toString nixpkgsPath)}/";
    in
    upstream (
      args
      // {
        transformOptions =
          option:
          let
            transformed = upstreamTransform option;
          in
          transformed
          // {
            declarations = map (
              declaration:
              if builtins.isAttrs declaration then
                declaration
              else
                let
                  declarationText = toString declaration;
                in
                if lib.hasPrefix nixpkgsPrefix declarationText then
                  lib.removePrefix nixpkgsPrefix declarationText
                else
                  declaration
            ) transformed.declarations;
          };
      }
    );
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      nixosOptionsDoc = wrapNixosOptionsDoc prev.path prev.nixosOptionsDoc;
    })
  ];
}
