{
  lib,
  parsers,
  root,
}:
let
  # Pick up new languages from the project's tracked source automatically.
  extensions = lib.unique (
    map (path: lib.last (lib.splitString "." (builtins.baseNameOf path))) (
      lib.filesystem.listFilesRecursive root
    )
  );
  filetypes = {
    cs = "c_sharp";
    ex = "elixir";
    exs = "elixir";
    h = "c";
    hpp = "cpp";
    js = "javascript";
    jsx = "javascript";
    kt = "kotlin";
    md = "markdown";
    mdx = "markdown";
    py = "python";
    rb = "ruby";
    rs = "rust";
    sh = "bash";
    tf = "hcl";
    ts = "typescript";
    yml = "yaml";
    zsh = "bash";
  };
  detected = map (extension: filetypes.${extension} or extension) extensions;
  # Keep common embedded languages available even without standalone source files.
  common = [
    "bash"
    "c_sharp"
    "css"
    "html"
    "javascript"
    "json"
    "lua"
    "markdown"
    "markdown_inline"
    "nix"
    "python"
    "regex"
    "rust"
    "scss"
    "sql"
    "toml"
    "typescript"
    "vim"
    "vimdoc"
    "xml"
    "yaml"
  ];
in
map (name: parsers.${name}) (
  builtins.filter (name: builtins.hasAttr name parsers) (lib.unique (common ++ detected))
)
