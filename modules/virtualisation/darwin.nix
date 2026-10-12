{
  orbStack = _: {
    home = _: {
      home.shellAliases.o = "orb";
      programs.zsh.profileExtra = ''
        if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
          source "$HOME/.orbstack/shell/init.zsh"
        fi
      '';
    };
  };
}
