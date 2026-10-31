{ pkgs }:

let
  inherit (pkgs) lib;
  plugins = with pkgs.vimPlugins; [
    snacks-nvim
    blink-cmp
    which-key-nvim
    lualine-nvim
    nvim-lspconfig
    conform-nvim
    (nvim-treesitter.withPlugins (
      parsers: with parsers; [
        bash
        json
        lua
        markdown
        markdown_inline
        nix
        python
        vim
        vimdoc
        yaml
      ]
    ))
  ];
  runtimePackages = with pkgs; [
    fd
    ripgrep
    jujutsu
    jjui
    nixd
    lua-language-server
    basedpyright
    bash-language-server
    yaml-language-server
    vscode-langservers-extracted
    nixfmt
    shfmt
    stylua
    ruff
    prettier
  ];
  portableInit = pkgs.writeText "terminal-nvim-init.lua" ''
    ${lib.concatMapStringsSep "\n" (plugin: ''vim.opt.runtimepath:prepend("${plugin}")'') plugins}
    package.preload["editor.profiles"] = function()
      return dofile("${./profiles.lua}")
    end
    dofile("${./init.lua}")
  '';
  nvim = pkgs.writeShellApplication {
    name = "editor-nvim";
    runtimeInputs = runtimePackages;
    text = ''
      export NVIM_APPNAME=terminal-editor
      exec ${lib.getExe pkgs.neovim} -u ${portableInit} "$@"
    '';
  };
  workspace = pkgs.writeShellApplication {
    name = "terminal-editor";
    runtimeInputs = [
      nvim
      pkgs.zellij
    ];
    text = ''
      exec zellij --config ${./zellij.kdl} --layout ${./layout.kdl} "$@"
    '';
  };
in
{
  inherit
    plugins
    runtimePackages
    nvim
    workspace
    ;
  zellijSettings.default_mode = "locked";
}
