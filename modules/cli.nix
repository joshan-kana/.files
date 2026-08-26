{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles;
  primaryHome = "${cfg.users.primary.homeRoot}/${cfg.users.primary.name}";
  repoPath =
    if cfg.paths.repoPath != null then cfg.paths.repoPath else "${primaryHome}/${cfg.paths.repoName}";
  scopeEnabled = path: lib.attrByPath (path ++ [ "enable" ]) null cfg.scopes != false;
  systemCommands = {
    cd = "cd $DOTFILES";
    edit = "if command -v code >/dev/null 2>&1; then code \"$DOTFILES/edit_config.code-workspace\"; else \${EDITOR:-nvim} \"$DOTFILES\"; fi";
    flakeUpdate = "${repoPath}/scripts/nix-flake-update ${repoPath} ${cfg.profile.name}";
    rebuild =
      action: "nh os ${action} \"$DOTFILES\" --hostname \"$FLK_PROFILE\" -- $NIXOS_REBUILD_FLAGS";
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
  };
  gitSettings = {
    user = {
      name = cfg.users.primary.fullName;
      email = cfg.users.primary.email;
    };
    init.defaultBranch = "main";
  };
  gitSigningFormat = "openpgp";
  toml = pkgs.formats.toml { };
  tuicrConfig = toml.generate "tuicr-config.toml" {
    theme = "stylix";
    diff_view = "side-by-side";
    show_file_list = true;
    mouse = true;
    wrap = false;
    relative_line_numbers = false;
    cursor_line = true;
    transparent_background = false;
    review_watch_interval_ms = 1000;
    no_update_check = true;
    username = cfg.users.primary.fullName;
    comment_types = [
      {
        id = "issue";
        definition = "problem that should be fixed before merge";
      }
      {
        id = "suggestion";
        definition = "possible improvement";
      }
      {
        id = "note";
        definition = "context or clarification";
      }
      {
        id = "praise";
        definition = "positive observation";
      }
    ];
  };
in
{
  environment.sessionVariables = {
    DOTFILES = repoPath;
    FLK_PROFILE = cfg.profile.name;
    OLLAMA_URL = cfg.services.ollama.url;
    NIXOS_REBUILD_FLAGS = cfg.rebuild.flags;
  };

  nh = _: {
    programs.nh.flake = repoPath;

    home = _: {
      programs.zsh.shellAliases = systemAliases // {
        inherit (systemCommands) edit;
      };
    };
  };

  direnv = _: {
    programs.direnv = {
      silent = true;
      enableZshIntegration = false;
    };

    home = _: {
      programs.zsh.shellAliases = {
        da = "direnv allow";
        dt = "direnv_hook_toggle";
      };
    };
  };

  clipboard = { lib, ... }: {
    home = _: {
      programs.zsh.shellAliases.cpd = lib.mkDefault ''
        printf "%s" "$(pwd | tr -d "\n")" | wl-copy && echo "Copied path!"
      '';
    };
  };

  ollama = _: {
    home = _: {
      programs.zsh.shellAliases.ollama = "docker exec -it ollama ollama";
    };
  };

  git = _: {
    programs.git.config = gitSettings // {
      gpg.format = gitSigningFormat;
    };

    home = _: {
      programs = {
        git = {
          settings =
            gitSettings
            //
              lib.optionalAttrs
                (scopeEnabled [
                  "cli"
                  "tuicr"
                ])
                {
                  alias.review = "!tuicr -w";
                };
          signing.format = gitSigningFormat;
        };
        zsh.shellAliases = {
          gs = "git status";
          gl = "git log";
          gd = "git diff";
          ga = "git add";
          gc = "git commit -m";
          gca = "git commit -a -m";
          gpl = "git pull";
          gph = "git push";
        };
      };
    };
  };

  zsh = _: {
    programs.zsh.enableBashCompletion = true;
    users.defaultUserShell = pkgs.zsh;

    home = _: {
      programs.zsh = {
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
        plugins = [
          {
            name = "zsh-fzf-tab";
            file = "share/fzf-tab/fzf-tab.plugin.zsh";
            src = pkgs.zsh-fzf-tab;
          }
        ];
        shellAliases = {
          bk = "cd ..";
          sz = "du -sh";
        };
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
              "*:flake input:(''${(j:|:)flake_inputs})"
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
    };
  };

  yazi = _: {
    programs.yazi.enable = true;

    home = _: {
      programs.yazi.shellWrapperName = "y";
    };
  };

  gh = _: {
    environment.systemPackages = [ pkgs.gh ];
    nixpkgs.overlays = (import ../overlays/gh-dash.nix { }).nixpkgs.overlays;

    home = _: {
      programs.gh.extensions = [ pkgs.gh-dash ];
      programs.zsh.shellAliases.dh = "gh dash";
      xdg.configFile."gh-dash/config.yml" = {
        source = (pkgs.formats.yaml { }).generate "gh-dash-config.yml" {
          defaults = {
            view = "issues";
            layout = {
              issues = {
                repo.hidden = true;
                creator.hidden = true;
                reactions.hidden = true;
                comments.hidden = true;
                updatedAt.hidden = true;
                createdAt.hidden = true;
              };
              projects = {
                enabled = true;
                fields = [
                  {
                    name = "Status";
                    width = 12;
                  }
                  {
                    name = "Priority";
                    width = 10;
                  }
                  {
                    name = "Area";
                    width = 14;
                  }
                  {
                    name = "Kind";
                    width = 12;
                  }
                ];
              };
            };
          };
          include = [ "stylix.yml" ];
          pager.diff = ''sh -c 'pager="$(git config --get pager.diff || git config --get core.pager)"; [ -n "$pager" ] || exec cat; exec sh -c "$pager"' '';
          repoPaths = {
            "joshan-kana/.files" = repoPath;
          };
          theme.ui.table.compact = true;
        };
      };
    };
  };

  delta = _: {
    home = { config, ... }: {
      programs.delta = {
        enableGitIntegration = config.programs.git.enable;
        options = {
          navigate = true;
          line-numbers = true;
        };
      };
    };
  };

  tuicr = _: {
    nixpkgs.overlays = [
      (_final: prev: {
        tuicr = inputs.nixpkgs.legacyPackages.${prev.stdenv.hostPlatform.system}.tuicr;
      })
    ];

    home = _: {
      home.packages = [ pkgs.tuicr ];
      xdg.configFile."tuicr/config.toml".source = tuicrConfig;
    };
  };

  lazygit = _: {
    home = _: {
      programs.lazygit.settings.git.diffRenderers = [
        {
          colorArg = "always";
          command = ''sh -c 'pager="$(git config --get pager.diff || git config --get core.pager)"; [ -n "$pager" ] || exec cat; PAGER=cat exec sh -c "$pager"' '';
        }
      ];
    };
  };

  starship = _: {
    home = _: {
      programs.starship = {
        enableZshIntegration = true;
        settings = {
          character.success_symbol = "[➜](bold green) ";
          character.error_symbol = "[✗](bold red) ";
          container.disabled = true;
        };
      };
    };
  };

  tmux = _: {
    home = _: {
      programs.tmux.enable = true;
    };
  };

  tmuxai = _: {
    home = _: {
      home.packages = [ pkgs.tmuxai ];
      home.file.".config/tmuxai/config.yaml".text = ''
        models:
          primary:
            provider: openrouter
            model: gemma3:12b
            api_key: XXXXXXXXXXXXXXX
            base_url: ${cfg.services.ollama.url}
      '';
    };
  };

  zellij = _: {
    home = _: {
      programs.zellij.enable = true;
    };
  };

  fzf = _: {
    home = _: {
      programs.fzf = {
        enableZshIntegration = true;
        defaultOptions = [ "--walker-skip=.git,.direnv,.Trash,Library,OrbStack" ];
      };
    };
  };

  ripgrep = _: {
    home = _: {
      programs.ripgrep.enable = true;
    };
  };

  lf = _: {
    home = _: {
      programs.lf.enable = true;
    };
  };

  bat = _: {
    home = _: {
      programs.bat.enable = true;
    };
  };

  eza = _: {
    home = _: {
      programs = {
        eza.enable = true;
        zsh.shellAliases = {
          l = "eza -a";
          ll = "eza -lah";
          ls = "eza";
        };
      };
    };
  };

  htop = _: {
    environment.systemPackages = [ pkgs.htop ];

    home = _: {
      programs.htop.enable = true;
    };
  };

  btop = _: {
    home = _: {
      programs.btop.settings.update_ms = 100;
    };
  };

  neovim = _: {
    home = _: {
      programs = {
        neovim = {
          withRuby = false;
          withPython3 = false;
          extraConfig = ''
            autocmd BufRead * autocmd FileType <buffer> ++once
            \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
          '';
        };
        zsh.shellAliases.v = "nvim";
      };
    };
  };

  mpv = _: {
    home = _: {
      programs = {
        mpv.scripts = with pkgs; [ mpvScripts.mpris ];
        zsh.shellAliases.p = "mpv --audio-pitch-correction=no --loop=yes";
      };
    };
  };

  vim = _: {
    environment.systemPackages = [ pkgs.vim ];
  };

  wget = _: {
    environment.systemPackages = [ pkgs.wget ];
  };

  lshw = _: {
    environment.systemPackages = [ pkgs.lshw ];
  };

  fastfetch = _: {
    environment.systemPackages = [ pkgs.fastfetch ];

    home = _: {
      programs.zsh.shellAliases.neofetch = "fastfetch";
    };
  };

  tree = _: {
    environment.systemPackages = [ pkgs.tree ];
  };

  glow = _: {
    environment.systemPackages = [ pkgs.glow ];
  };

  stow = _: {
    environment.systemPackages = [ pkgs.stow ];
  };

  youtubeTui = _: {
    environment.systemPackages = [ pkgs.youtube-tui ];
  };

  killall = _: {
    environment.systemPackages = [ pkgs.killall ];
  };

  xdgUtils = _: {
    environment.systemPackages = [ pkgs.xdg-utils ];
  };

  trashCli = _: {
    environment.systemPackages = [ pkgs.trash-cli ];
  };

  gnumake = _: {
    environment.systemPackages = [ pkgs.gnumake ];
  };

  devbox = _: {
    environment.systemPackages = [ pkgs.devbox ];
  };

  has = _: {
    environment.systemPackages = [ pkgs.has ];
  };

  nvd = _: {
    environment.systemPackages = [ pkgs.nvd ];
  };

  nixTree = _: {
    environment.systemPackages = [ pkgs.nix-tree ];
  };

  python = _: {
    environment.systemPackages = [ pkgs.python3 ];
  };

  ncmpcpp = _: {
    home = _: {
      programs.ncmpcpp.package = pkgs.ncmpcpp.override { visualizerSupport = true; };
    };
  };

  cava = _: {
    home = { config, ... }: {
      programs.cava.settings = {
        general.lower_cutoff_freq = 20;
        general.upper_cutoff_freq = 20000;
        smoothing.noise_reduction = 30;
        smoothing.monstercat = 1;
        general.bar_width = 1;
        general.bar_spacing = 0;
        output.channels = "mono";
        color.gradient = 1;
        color.gradient_count = 8;
        color.gradient_color_1 = "'#${config.lib.stylix.colors.base01}'";
        color.gradient_color_2 = "'#${config.lib.stylix.colors.base02}'";
        color.gradient_color_3 = "'#${config.lib.stylix.colors.base03}'";
        color.gradient_color_4 = "'#${config.lib.stylix.colors.base04}'";
        color.gradient_color_5 = "'#${config.lib.stylix.colors.base05}'";
        color.gradient_color_6 = "'#${config.lib.stylix.colors.base06}'";
        color.gradient_color_7 = "'#${config.lib.stylix.colors.base07}'";
        color.gradient_color_8 = "'#${config.lib.stylix.colors.base08}'";
      };
    };
  };

  restic = import ./cli/restic.nix;
}
