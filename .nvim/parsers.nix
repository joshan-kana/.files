{
  lib,
  parsers,
  root,
}:
let
  sources = lib.filesystem.listFilesRecursive root;
  markdown = builtins.filter (
    path:
    lib.any (extension: lib.hasSuffix extension (toString path)) [
      ".md"
      ".mdx"
    ]
  ) sources;

  # One source for grammar selection and Markdown fence language aliases.
  languageAliases = builtins.fromJSON (builtins.readFile ./language-aliases.json);

  sourceLanguages = map (path: lib.last (lib.splitString "." (builtins.baseNameOf path))) sources;
  fencedLanguages = lib.concatMap (
    path:
    lib.concatMap (
      line:
      let
        match = builtins.match "^[[:blank:]]*(```|~~~)[[:blank:]]*([A-Za-z_][A-Za-z0-9_+.-]*).*" line;
      in
      if match == null then [ ] else [ (builtins.elemAt match 1) ]
    ) (lib.splitString "\n" (builtins.readFile path))
  ) markdown;
  injectedLanguages = lib.concatMap (
    path:
    lib.concatMap (
      line:
      let
        match = builtins.match ".*injection[.]language \"([A-Za-z0-9_+-]+)\".*" line;
      in
      if match == null then [ ] else match
    ) (lib.splitString "\n" (builtins.readFile path))
  ) [ ./queries/nix/injections.scm ];

  # Editor/Markdown helper grammars, not a separate registry of project languages.
  infrastructure = [
    "markdown_inline"
    "regex"
    "vim"
    "vimdoc"
  ];
  discovered = map (name: languageAliases.${lib.toLower name} or (lib.toLower name)) (
    sourceLanguages ++ fencedLanguages ++ injectedLanguages
  );
in
map (name: parsers.${name}) (
  builtins.filter (name: builtins.hasAttr name parsers) (lib.unique (infrastructure ++ discovered))
)
