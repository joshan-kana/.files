{
  config,
  inputs,
  pkgs,
  ...
}:

let
  inherit (config) dotfiles;
  inherit (dotfiles.users) primary;
  repoPath = dotfiles.paths.repoPath;
  systemCommands = {
    cd = "cd $DOTFILES";
    flakeUpdate = "${repoPath}/scripts/nix-flake-update ${repoPath} ${dotfiles.profile.name}";
    rebuild =
      action: "nh os ${action} \"$DOTFILES\" --hostname \"$FLK_PROFILE\" -- $NIXOS_REBUILD_FLAGS";
  };
  systemAliases = {
    syscd = systemCommands.cd;
    scd = systemCommands.cd;
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
      name = primary.fullName;
      inherit (primary) email;
    };
    init.defaultBranch = "main";
    pull.rebase = true;
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
    username = primary.fullName;
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

  # Module-shaped common fragments intentionally keep native option paths in
  # the let block so nixd can provide completion/hover there in both the NixOS
  # and Home Manager contexts. When the native schemas differ, keep shared data
  # in an ordinary let value instead (as with gitSettings above).
  nhConfig = _: {
    programs.nh.flake = repoPath;
  };

  direnvConfig = _: {
    programs.direnv = {
      silent = true;
      enableZshIntegration = false;
    };
  };

  zshConfig = _: {
    programs.zsh.enableCompletion = true;
  };

  lazygitConfig = _: {
    programs.lazygit.settings.git.diffRenderers = [
      {
        colorArg = "always";
        command = ''sh -c 'pager="$(git config --get pager.diff || git config --get core.pager)"; [ -n "$pager" ] || exec cat; PAGER=cat exec sh -c "$pager"' '';
      }
    ];
  };

  starshipConfig = _: {
    programs.starship.settings = {
      character.success_symbol = "[➜](bold green) ";
      character.error_symbol = "[✗](bold red) ";
      container.disabled = true;
    };
  };

  neovimConfig = _: {
    programs.neovim = {
      withRuby = false;
      withPython3 = false;
    };
  };
  sessionVariables = {
    DOTFILES = repoPath;
    FLK_PROFILE = dotfiles.profile.name;
    OLLAMA_URL = dotfiles.services.ollama.url;
    NIXOS_REBUILD_FLAGS = dotfiles.rebuild.flags;
  };
in
{
  environment.sessionVariables = sessionVariables;

  home = _: {
    home.sessionVariables = sessionVariables;
  };

  nh =
    args:
    let
      aliases = systemAliases // {
        edit = "edit-config";
        sedit = "edit-config";
        sysedit = "edit-config";
      };
      editConfig = pkgs.writeShellApplication {
        name = "edit-config";
        text = ''
          if command -v code >/dev/null 2>&1; then
            code "$DOTFILES/edit_config.code-workspace"
          else
            "''${EDITOR:-nvim}" "$DOTFILES"
          fi
        '';
      };
      completion = ''
        _sysfu() {
          _arguments -C \
            '(-h --help)'{-h,--help}'[show help]' \
            '--input-ref[pin one input to a specific flake ref]:input=flake-ref:' \
            '--nixpkgs-ref[pin nixpkgs to a revision, branch, or flake ref]:rev-or-ref:' \
            '--choose-nixpkgs-ref[choose from recent nixpkgs commits on a branch]:branch:(nixos-unstable nixos-25.05 nixos-24.11)' \
            "*:flake input:(''${(j:|:)flake_inputs})"
        }
        compdef _sysfu sysfu
      '';
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [ editConfig ];
      programs = (nhConfig args).programs // {
        zsh.interactiveShellInit = completion;
      };

      home = args: {
        home.packages = [ editConfig ];
        home.shellAliases = aliases;
        programs = (nhConfig args).programs // {
          zsh.initContent = completion;
        };
      };
    };

  direnv =
    args:
    let
      aliases.da = "direnv allow";
      zshAliases.dt = "direnv_hook_toggle";
      hook = ''
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
    in
    {
      environment.shellAliases = aliases;
      programs = (direnvConfig args).programs // {
        zsh = {
          shellAliases = zshAliases;
          interactiveShellInit = hook;
        };
      };

      home = args: {
        home.shellAliases = aliases;
        programs = (direnvConfig args).programs // {
          zsh = {
            shellAliases = zshAliases;
            initContent = hook;
          };
        };
      };
    };

  clipboard =
    { lib, pkgs, ... }:
    let
      aliases = {
        cpd = "copy-path";
      };
      copyPath = pkgs.writeShellApplication {
        name = "copy-path";
        runtimeInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.wl-clipboard ];
        text = ''
          if command -v pbcopy >/dev/null 2>&1; then
            printf "%s" "$PWD" | pbcopy
            echo "Copied path to macOS clipboard"
          elif command -v wl-copy >/dev/null 2>&1; then
            printf "%s" "$PWD" | wl-copy
            echo "Copied path!"
          else
            echo "copy-path: no supported clipboard command found" >&2
            exit 1
          fi
        '';
      };
    in
    {
      environment.systemPackages = [ copyPath ];
      environment.shellAliases = aliases;

      home = _: {
        home.packages = [ copyPath ];
        home.shellAliases = aliases;
      };
    };

  ollama =
    _:
    let
      aliases = {
        ollama = "docker exec -it ollama ollama";
      };
    in
    {
      environment.shellAliases = aliases;

      home = _: {
        home.shellAliases = aliases;
      };
    };

  git =
    _:
    let
      aliases = {
        gs = "git status";
        gl = "git log";
        gb = "git branch -a";
        gd = "git diff";
        ga = "git add";
        gc = "git commit -m";
        gca = "git commit -a -m";
        gpl = "git pull";
        gph = "git push";
      };
    in
    {
      environment.shellAliases = aliases;
      programs.git.config = gitSettings // {
        gpg.format = gitSigningFormat;
      };

      home = _: {
        home.shellAliases = aliases;
        programs.git = {
          settings = gitSettings;
          signing.format = gitSigningFormat;
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
          programs.git.settings.alias.review = "!tuicr -w";
          xdg.configFile."tuicr/config.toml".source = tuicrConfig;
        };
      };

      lazygit = args: {
        inherit (lazygitConfig args) programs;

        home = args: {
          inherit (lazygitConfig args) programs;
        };
      };
    };

  zsh =
    args:
    let
      aliases = {
        bk = "cd ..";
        sz = "du -sh";
      };
    in
    {
      environment.shellAliases = aliases;
      programs.zsh = (zshConfig args).programs.zsh // {
        enableBashCompletion = true;
      };
      users.defaultUserShell = pkgs.zsh;

      home = args: {
        home.shellAliases = aliases;
        programs.zsh = (zshConfig args).programs.zsh // {
          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          plugins = [
            {
              name = "zsh-fzf-tab";
              file = "share/fzf-tab/fzf-tab.plugin.zsh";
              src = pkgs.zsh-fzf-tab;
            }
          ];
          initContent = ''
            bindkey "^[[1;5D" backward-word
            bindkey "^[[1;5C" forward-word
            bindkey "^H" backward-kill-word
            bindkey "^[[3;3~" kill-word

            autoload -U edit-command-line
            zle -N edit-command-line
            bindkey '^xe' edit-command-line
            bindkey '^x^e' edit-command-line

            bindkey -v '^?' backward-delete-char
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

  gh =
    _:
    let
      aliases = {
        dh = "gh dash";
      };
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [
        pkgs.gh
        pkgs.gh-dash
      ];
      nixpkgs.overlays = (import ../../overlays/gh-dash.nix { }).nixpkgs.overlays;

      home = _: {
        home.shellAliases = aliases;
        programs.gh.extensions = [ pkgs.gh-dash ];
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

  starship = args: {
    inherit (starshipConfig args) programs;

    home = args: {
      programs.starship = (starshipConfig args).programs.starship // {
        enableZshIntegration = true;
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
            base_url: ${dotfiles.services.ollama.url}
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

  eza =
    _:
    let
      aliases = {
        l = "eza -a";
        ll = "eza -lah";
        ls = "eza";
      };
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [ pkgs.eza ];

      home = _: {
        home.shellAliases = aliases;
        programs.eza.enable = true;
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

  neovim =
    args:
    let
      aliases = {
        v = "nvim";
      };
    in
    {
      inherit (neovimConfig args) programs;
      environment.shellAliases = aliases;
      environment.sessionVariables.EDITOR = "nvim";

      home = args: {
        home.shellAliases = aliases;
        programs.neovim = (neovimConfig args).programs.neovim // {
          extraConfig = ''
            autocmd BufRead * autocmd FileType <buffer> ++once
            \ if &ft !~# 'commit\|rebase' && line("'\"") > 1 && line("'\"") <= line("$") | exe 'normal! g`"' | endif
          '';
        };
      };
    };

  mpv =
    _:
    let
      aliases = {
        p = "mpv --audio-pitch-correction=no --loop=yes";
      };
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [ pkgs.mpv ];

      home = _: {
        home.shellAliases = aliases;
        programs.mpv.scripts = with pkgs; [ mpvScripts.mpris ];
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

  fastfetch =
    _:
    let
      aliases = {
        neofetch = "fastfetch";
      };
    in
    {
      environment.shellAliases = aliases;
      environment.systemPackages = [ pkgs.fastfetch ];

      home = _: {
        home.shellAliases = aliases;
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

  systemdManagerTui = _: {
    environment.systemPackages = [ pkgs.systemd-manager-tui ];
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

  python3 = _: {
    environment.systemPackages = [ pkgs.python3 ];
  };

  ncmpcpp = _: {
    home = _: {
      programs.ncmpcpp.package = pkgs.ncmpcpp.override { visualizerSupport = true; };
    };
  };

  cava = _: {
    home = _: {
      programs.cava.settings = {
        general.lower_cutoff_freq = 20;
        general.upper_cutoff_freq = 20000;
        smoothing.noise_reduction = 30;
        smoothing.monstercat = 1;
        general.bar_width = 1;
        general.bar_spacing = 0;
        output.channels = "mono";
      };
    };
  };

}
