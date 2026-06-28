{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  cfg = osConfig.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
  repoPath =
    if cfg.paths.repoPath != null then cfg.paths.repoPath else "${primaryHome}/${cfg.paths.repoName}";
  enabled = name: !(builtins.elem name cfg.cli.disabledPrograms);
  systemCommands = {
    cd = "cd $DOTFILES";
    edit = "if command -v code >/dev/null 2>&1; then code \"$DOTFILES/edit_config.code-workspace\"; else \${EDITOR:-nvim} \"$DOTFILES\"; fi";
    flakeUpdate = "${repoPath}/scripts/nix-flake-update ${repoPath} ${cfg.profile.name}";
    rebuild =
      action: "sudo nixos-rebuild --flake $DOTFILES#$FLK_PROFILE $NIXOS_REBUILD_FLAGS ${action}";
  };
  systemAliases = {
    syscd = systemCommands.cd;
    scd = systemCommands.cd;
    sysedit = systemCommands.edit;
    sedit = systemCommands.edit;
    sysfu = systemCommands.flakeUpdate;
    sfu = systemCommands.flakeUpdate;
    sysbld = systemCommands.rebuild "build";
    sbld = systemCommands.rebuild "build";
    sysboot = systemCommands.rebuild "boot";
    sboot = systemCommands.rebuild "boot";
    sysup = systemCommands.rebuild "switch";
    sup = systemCommands.rebuild "switch";
    systest = systemCommands.rebuild "test";
    stest = systemCommands.rebuild "test";
    sysvm = systemCommands.rebuild "build-vm";
    svm = systemCommands.rebuild "build-vm";
  };
  baseAliases = systemAliases // {
    bk = "cd ..";
    edit = systemCommands.edit;
    h = "start-hyprland";
    HI = "${repoPath}/scripts/hyprland_intel";
    HN = "${repoPath}/scripts/hyprland_nvidia";
    k = "startplasma-wayland";
    gs = "git status";
    gl = "git log";
    gd = "git diff";
    ga = "git add";
    gc = "git commit -m";
    gca = "git commit -a -m";
    gpl = "git pull";
    gph = "git push";
    ollama = "docker exec -it ollama ollama";
    v = "nvim";
    l = "eza -a";
    ll = "eza -lah";
    ls = "eza";
    neofetch = "fastfetch";
    cpd = ''printf "%s" \"$(pwd | tr -d "\n")\" | wl-copy && echo "Copied path!"'';
    p = "mpv --audio-pitch-correction=no --loop=yes";
    sz = "du -sh";
    da = "direnv allow";
    dt = "direnv_hook_toggle";
  };
  aliases = lib.filterAttrs (name: _: !(builtins.elem name cfg.cli.disabledAliases)) (
    baseAliases // cfg.cli.aliasOverrides
  );
in
lib.mkIf cfg.features.cli.enable {
  programs.git = lib.mkIf (enabled "git") {
    enable = true;
    settings = {
      user = {
        name = cfg.users.primary.fullName;
        email = cfg.users.primary.email;
      };
      extraConfig = {
        init.defaultBranch = "main";
      };
    };
    signing.format = "openpgp";
  };

  programs.zsh = lib.mkIf (enabled "zsh") {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    plugins = [
      {
        name = "zsh-fzf-tab";
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
        src = pkgs.zsh-fzf-tab;
      }
    ];
    shellAliases = aliases;
    initContent = ''
      bindkey "^[[1;5D" backward-word
      bindkey "^[[1;5C" forward-word
      bindkey "^H" backward-kill-word
      bindkey "^[[3;3~" kill-word

      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey '^xe' edit-command-line
      bindkey '^x^e' edit-command-line

      _sysfu() {
        _arguments -C \
          '(-h --help)'{-h,--help}'[show help]' \
          '--input-ref[pin one input to a specific flake ref]:input=flake-ref:' \
          '--nixpkgs-ref[pin nixpkgs to a revision, branch, or flake ref]:rev-or-ref:' \
          '--choose-nixpkgs-ref[choose from recent nixpkgs commits on a branch]:branch:(nixos-unstable nixos-25.05 nixos-24.11)' \
          '*:flake input:(nixpkgs nixpkgs-stable nixos-hardware home-manager stylix spicetify-nix plasma-manager)'
      }
      compdef _sysfu sysfu

      bindkey -v '^?' backward-delete-char

      _direnv_hook() {
        trap -- ''' SIGINT
        eval "$("${pkgs.direnv}/bin/direnv" export zsh)"
        trap - SIGINT
      }

      direnv_hook_disable() {
        typeset -ag precmd_functions
        if (( ''${precmd_functions[(I)_direnv_hook]} )); then
          precmd_functions=(''${precmd_functions:#_direnv_hook})
        fi
        typeset -ag chpwd_functions
        if (( ''${chpwd_functions[(I)_direnv_hook]} )); then
          chpwd_functions=(''${chpwd_functions#_direnv_hook})
        fi
      }

      direnv_hook_enable() {
        typeset -ag precmd_functions
        if (( ! ''${precmd_functions[(I)_direnv_hook]} )); then
          precmd_functions=(_direnv_hook $precmd_functions)
        fi
        typeset -ag chpwd_functions
        if (( ! ''${chpwd_functions[(I)_direnv_hook]} )); then
          chpwd_functions=(_direnv_hook $chpwd_functions)
        fi
      }

      direnv_hook_toggle() {
        typeset -ag precmd_functions
        if (( ''${precmd_functions[(I)_direnv_hook]} )); then
          direnv_hook_disable
        else
          direnv_hook_enable
        fi
      }

      direnv_hook_enable
    '';
  };

  programs.starship = lib.mkIf (enabled "starship") {
    enable = true;
    enableZshIntegration = true;
    settings = {
      character.success_symbol = "[➜](bold green) ";
      character.error_symbol = "[✗](bold red) ";
      container.disabled = true;
    };
  };

  programs.tmux.enable = enabled "tmux";

  home.file.".config/tmuxai/config.yaml" = lib.mkIf (enabled "tmuxai") {
    text = ''
      models:
        primary:
          provider: openrouter
          model: gemma3:12b
          api_key: XXXXXXXXXXXXXXX
          base_url: ${cfg.services.ollama.url}
    '';
  };

  programs.zellij.enable = enabled "zellij";
  programs.fzf = lib.mkIf (enabled "fzf") {
    enable = true;
    enableZshIntegration = true;
  };
  programs.ripgrep.enable = enabled "ripgrep";
  programs.lf.enable = enabled "lf";
  programs.bat.enable = enabled "bat";
  programs.eza.enable = enabled "eza";
  programs.htop.enable = enabled "htop";
  programs.btop = lib.mkIf (enabled "btop") {
    enable = true;
    settings.update_ms = 100;
  };
  programs.yazi = lib.mkIf (enabled "yazi") {
    enable = true;
    shellWrapperName = "y";
  };
  programs.neovim = lib.mkIf (enabled "neovim") {
    enable = true;
    withRuby = false;
    withPython3 = false;
    extraConfig = ''
      autocmd BufRead * autocmd FileType <buffer> ++once
      \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
    '';
  };
  programs.mpv = lib.mkIf (enabled "mpv") {
    enable = true;
    scripts = with pkgs; [ mpvScripts.mpris ];
  };
}
