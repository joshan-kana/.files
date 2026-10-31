{
  config,
  configurationFlakeSubdirectory,
  configurationOutputName,
  pkgs,
  lib,
  system,
  ...
}:

let
  inherit (lib.systems.elaborate system) isDarwin isLinux;
  inherit (config) dotfiles;
  inherit (dotfiles.defaults) editor;
  inherit (dotfiles.users) primary;
  repoPath = dotfiles.paths.repoPath;
  gitSettings = {
    user = {
      name = primary.fullName;
      inherit (primary) email;
    };
    init.defaultBranch = "main";
    pull.rebase = true;
    commit.verbose = true;
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
        id = "explain";
        definition = "Explain what the selected code does, how it works, and why it is required here.";
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
    EDITOR = editor;
    VISUAL = editor;
    FLK_PROFILE = configurationOutputName;
    NH_OS_FLAKE =
      if configurationFlakeSubdirectory == null then
        repoPath
      else
        "${repoPath}/${configurationFlakeSubdirectory}";
    OLLAMA_URL = dotfiles.services.ollama.url;
    NIXOS_REBUILD_FLAGS = dotfiles.rebuild.flags;
  };

in
{
  home = _: {
    home.sessionVariables = sessionVariables;
  };

  systemCommands =
    _:
    let
      commands = {
        cd = "cd $DOTFILES";
        systemUpdate = "nix run ${repoPath}#system-update --";
      }
      // lib.optionalAttrs isDarwin {
        rebuild = action: ''nh darwin ${action} --hostname "$FLK_PROFILE"'';
      }
      // lib.optionalAttrs isLinux {
        rebuild = action: ''nh os ${action} --hostname "$FLK_PROFILE" $NIXOS_REBUILD_FLAGS'';
      };
      editConfig = pkgs.writeShellApplication {
        name = "edit-config";
        text = ''
          if command -v code >/dev/null 2>&1; then
            code "$DOTFILES/edit_config.code-workspace"
          else
            "''${EDITOR:-${editor}}" "$DOTFILES"
          fi
        '';
      };
    in
    {
      home = _: {
        home.packages = [ editConfig ];
        home.sessionVariables = lib.optionalAttrs isLinux {
          NH_ELEVATION_STRATEGY = "${pkgs.systemd}/bin/run0";
        };
        home.shellAliases = {
          syscd = commands.cd;
          scd = commands.cd;
          sysfu = commands.systemUpdate;
          sfu = commands.systemUpdate;
          sysbld = commands.rebuild "build";
          sbld = commands.rebuild "build";
          sysup = commands.rebuild "switch";
          sup = commands.rebuild "switch";
          edit = "edit-config";
          sedit = "edit-config";
          sysedit = "edit-config";
        }
        // lib.optionalAttrs isLinux {
          sysboot = commands.rebuild "boot";
          sbt = commands.rebuild "boot";
          systest = commands.rebuild "test";
          stst = commands.rebuild "test";
        };
      };

      vm =
        { pkgs, ... }:
        lib.optionalAttrs isLinux (
          let
            buildVm = pkgs.writeShellApplication {
              name = "build-vm";
              text = ''
                read -r -a rebuildFlags <<< "''${NIXOS_REBUILD_FLAGS:-}"
                ${pkgs.systemd}/bin/run0 nixos-rebuild --flake "$NH_OS_FLAKE#$FLK_PROFILE" "''${rebuildFlags[@]}" build-vm
              '';
            };
          in
          {
            home = _: {
              home.shellAliases = {
                sysvm = "build-vm";
                svm = "build-vm";
              };
              home.packages = [ buildVm ];
            };
          }
        );
    };

  nh =
    args:
    {
      home = args: {
        inherit ((nhConfig args)) programs;
      };
    }
    // lib.optionalAttrs isLinux {
      # The rebuild helper must also be available to system administrators.
      programs = lib.recursiveUpdate (nhConfig args).programs {
        nh.enable = true;
      };
    };

  direnv =
    _args:
    let
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
      home = args: {
        home.shellAliases = {
          da = "direnv allow";
          db = "direnv block";
          dr = "direnv reload";
        };
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
      home = _: {
        home.packages = [ copyPath ];
        home.shellAliases.cpd = "copy-path";
      };
    };

  ollama =
    _:
    lib.optionalAttrs isLinux {
      home = _: {
        home.shellAliases.ollama = "docker exec -it ollama ollama";
      };
    };

  jujutsu =
    _:
    let
      prView = pkgs.writeShellApplication {
        name = "jj-pr-view";
        runtimeInputs = [
          pkgs.gh
          pkgs.jujutsu
        ];
        text = ''
          bookmark="$(jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")')"
          if [[ -z "$bookmark" ]]; then
            echo "jj-pr-view: current change has no bookmark" >&2
            exit 1
          fi

          exec gh pr view "$bookmark" "$@"
        '';
      };
      review = pkgs.writeShellApplication {
        name = "jj-review";
        runtimeInputs = [
          pkgs.gh
          pkgs.git
          pkgs.jujutsu
        ];
        text = ''
          revision="''${1:-@}"
          if (( $# > 1 )); then
            echo "usage: jr [revision]" >&2
            exit 2
          fi

          change_id="$(jj log -r "$revision" --no-graph -T 'change_id.short(12)')"
          title="$(jj log -r "$revision" --no-graph -T 'description.first_line()')"
          if [[ -z "$title" ]]; then
            echo "jj-review: change has no description; run 'j describe' first" >&2
            exit 1
          fi

          bookmark="jj/$change_id"
          base="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)"
          jj bookmark set --allow-backwards "$bookmark" -r "$revision"
          jj git push --bookmark "$bookmark"

          if url="$(gh pr view "$bookmark" --json url --jq .url 2>/dev/null)"; then
            printf '%s\n' "$url"
          else
            gh pr create --base "$base" --head "$bookmark" --fill
          fi
        '';
      };
      tuicrReview = pkgs.writeShellApplication {
        name = "jj-tuicr-review";
        runtimeInputs = [
          pkgs.gh
          pkgs.jujutsu
          pkgs.tuicr
        ];
        text = ''
          bookmark="$(jj log -r @ --no-graph -T 'bookmarks.map(|b| b.name()).join(" ")')"
          if [[ -z "$bookmark" ]]; then
            echo "jj-tuicr-review: current change has no bookmark" >&2
            exit 1
          fi

          url="$(gh pr view "$bookmark" --json url --jq .url)"
          exec tuicr pr "$url"
        '';
      };
    in
    {
      home = _: {
        home.packages = [
          prView
          review
          tuicrReview
        ];
        home.shellAliases = {
          j = "jj";
          jpl = "jj git fetch && jj rebase -d 'trunk()'";
          js = "jj st";
          jd = "jj diff";
          jl = "jj log";
          jpr = "jj-pr-view";
          jr = "jj-review";
          jtr = "jj-tuicr-review";
        };
        programs.jujutsu = {
          enable = true;
          settings.user = gitSettings.user;
        };
      };
    };

  git =
    _:
    let
      stash = pkgs.writeShellApplication {
        name = "git-stash-editor";
        runtimeInputs = [ pkgs.git ];
        text = ''
          if [ "$#" -gt 0 ]; then
            exec git stash "$@"
          fi

          message_file="$(mktemp)"
          trap 'rm -f "$message_file"' EXIT

          editor="$(git var GIT_EDITOR)"
          eval "$editor \"\$message_file\""

          message="$(git stripspace --strip-comments < "$message_file")"
          if [ -z "$message" ]; then
            echo "Aborting stash due to empty message." >&2
            exit 1
          fi

          exec git stash push -m "$message"
        '';
      };
    in
    {
      home = _: {
        home.packages = [ stash ];
        home.shellAliases = {
          gs = "git status";
          gf = "git fetch --prune";
          gl = "git log";
          gb = "git branch -avv";
          gw = "git switch";
          gou = "git checkout";
          gd = "git diff";
          ga = "git add";
          grt = "git restore";
          gc = "git commit";
          gca = "git commit -a";
          gst = "git-stash-editor";
          gpl = "git pull";
          gph = "git push";
          gphf = "git push --force-with-lease";
        };
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
        home = _: {
          home.packages = [ pkgs.tuicr ];
          home.shellAliases.tre = "tuicr -r origin/HEAD..HEAD -w";
          programs.git.settings.alias.review = "!tuicr -w";
          xdg.configFile."tuicr/config.toml".source = tuicrConfig;
        };
      };

      lazygit = _args: {
        home = args: {
          inherit (lazygitConfig args) programs;
        };
      };
    }
    // lib.optionalAttrs isLinux {
      # Git remains available for system recovery even without Home Manager.
      programs.git.enable = true;
    };

  zsh =
    args:
    {
      home = args: {
        home.shellAliases = {
          bk = "cd ..";
          sz = "dust";
        };
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
    }
    // lib.optionalAttrs isLinux {
      programs.zsh = (zshConfig args).programs.zsh // {
        enable = true;
        enableBashCompletion = true;
      };
      users.defaultUserShell = pkgs.zsh;
    };

  yazi = _: {
    home = _: {
      programs.yazi.shellWrapperName = "y";
    };
  };

  gh = _: {
    home = _: {
      home.shellAliases.dh = "gh dash";
      home.packages = [ pkgs.gh-dash ];
      programs.gh.extensions = [
        pkgs.gh-dash
        pkgs.gh-stack
      ];
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

  starship = _args: {
    home = args: {
      programs.starship = (starshipConfig args).programs.starship // {
        enableZshIntegration = true;
      };
    };
  };

  tmux = _: {
    home = _: {
      programs.tmux = { };
    };
  };

  zellij = _: {
    home = _: {
      programs.zellij = { };
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
      programs.ripgrep = { };
    };
  };

  lf = _: {
    home = _: {
      programs.lf = { };
    };
  };

  bat = _: {
    home = _: {
      programs.bat = { };
    };
  };

  eza = _: {
    home = _: {
      home.shellAliases = {
        l = "eza -a";
        ll = "eza -lah";
        ls = "eza";
      };
      programs.eza = { };
    };
  };

  htop = _: {
    home = _: {
      programs.htop = { };
    };
  };

  btop = _: {
    home = _: {
      programs.btop.settings.update_ms = 100;
    };
  };

  neovim = _args: {
    home = args: {
      home.shellAliases.v = "nvim";
      programs.neovim = (neovimConfig args).programs.neovim // {
        extraPackages = with pkgs; [
          fd
          ripgrep
          git
          jujutsu
          jjui
          nixd
          lua-language-server
          basedpyright
          bash-language-server
          yaml-language-server
          vscode-langservers-extracted
          nixfmt
          stylua
          ruff
          shfmt
          prettier
        ];
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
        initLua = builtins.readFile ./neovim/init.lua;
      };
      xdg.configFile."nvim/lua/editor/profiles.lua".source = ./neovim/profiles.lua;
    };
  };

  mpv = _: {
    home =
      _:
      let
        standard = {
          inverse-tone-mapping = "no";
          tone-mapping = "auto";
          target-peak = "auto";
          hdr-compute-peak = "auto";
          gamut-mapping-mode = "auto";
          target-trc = "auto";
          target-prim = "auto";
        };
        expanded = standard // {
          inverse-tone-mapping = "yes";
          tone-mapping = "spline";
          hdr-compute-peak = "no";
          gamut-mapping-mode = "perceptual";
        };
      in
      {
        home.shellAliases.p = "mpv --audio-pitch-correction=no --loop=yes";
        programs.mpv = {
          scripts = lib.optionals isLinux (with pkgs; [ mpvScripts.mpris ]);
          config = {
            demuxer-max-bytes = "3GiB";
            demuxer-max-back-bytes = "256MiB";
            target-colorspace-hint = "yes";
            input-commands-append = [
              ''keybind Ctrl+! "apply-profile hdr-standard ; show-text \"HDR: Standard\""''
              ''keybind Ctrl+@ "apply-profile hdr-expanded ; show-text \"HDR: Expanded\""''
              ''keybind Ctrl+SHARP "apply-profile sdr-to-hdr ; show-text \"HDR: SDR to HDR\""''
            ];
          };
          profiles = {
            hdr-standard = standard;
            hdr-expanded = expanded;
            sdr-to-hdr = expanded // {
              target-trc = "hlg";
              target-prim = "bt.2020";
            };
          };
        };
      };
  };

  vim = _: {
    home = _: {
      home.packages = [ pkgs.vim ];
    };
  };

  wget = _: {
    home = _: {
      home.packages = [ pkgs.wget ];
    };
  };

  lshw =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.lshw ];
    };

  fastfetch = _: {
    home = _: {
      home.packages = [ pkgs.fastfetch ];
      home.shellAliases.neofetch = "fastfetch";
    };
  };

  tree = _: {
    home = _: {
      home.packages = [ pkgs.tree ];
    };
  };

  glow = _: {
    home = _: {
      home.packages = [ pkgs.glow ];
    };
  };

  stow = _: {
    home = _: {
      home.packages = [ pkgs.stow ];
    };
  };

  systemdManagerTui =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.systemd-manager-tui ];
    };

  youtubeTui = _: {
    home = _: {
      home.packages = [ pkgs.youtube-tui ];
    };
  };

  ytDlp = _: {
    home = _: {
      home.packages = [ pkgs.yt-dlp ];
    };
  };

  killall =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.killall ];
    };

  xdgUtils =
    _:
    lib.optionalAttrs isLinux {
      environment.systemPackages = [ pkgs.xdg-utils ];
    };

  trashCli = _: {
    home = _: {
      home.packages = [ pkgs.trash-cli ];
    };
  };

  gnumake = _: {
    home = _: {
      home.packages = [ pkgs.gnumake ];
    };
  };

  devbox = _: {
    home = _: {
      home.packages = [ pkgs.devbox ];
    };
  };

  has = _: {
    home = _: {
      home.packages = [ pkgs.has ];
    };
  };

  nvd = _: {
    home = _: {
      home.packages = [ pkgs.nvd ];
    };
  };

  nixTree = _: {
    home = _: {
      home.packages = [ pkgs.nix-tree ];
    };
  };

  python3 = _: {
    home = _: {
      home.packages = [ pkgs.python3 ];
    };
  };

  ncmpcpp = _: {
    home = _: {
      programs.ncmpcpp = { };
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

  codex = _: {
    home = _: {
      programs.codex = { };
    };
  };

  dust = _: {
    home = _: {
      home.packages = [ pkgs.dust ];
    };
  };

  nixShell = _: {
    home = _: {
      home.packages = [
        (pkgs.writeShellApplication {
          name = "ns";
          text = ''
            if (( $# == 0 )); then
              echo "usage: ns package1 package2 ... [-- command args...]" >&2
              exit 2
            fi

            packages=()
            while (( $# )); do
              if [[ "$1" == "--" ]]; then
                shift
                break
              fi
              packages+=("nixpkgs#$1")
              shift
            done

            if (( $# )); then
              exec nix shell "''${packages[@]}" --command "$@"
            fi
            exec nix shell "''${packages[@]}"
          '';
        })
      ];
    };
  };

  spotifyPlayer = _: {
    home = _: {
      programs.spotify-player = {
        enable = true;
        settings = {
          client_id_command = {
            command = "cat";
            args = [
              "${dotfiles.secretsDir}/spotify-client-id"
            ];
          };

          login_redirect_uri = "http://127.0.0.1:8989/login";
        };
      };
      home.shellAliases.sp = "spotify_player";
    };
  };

}
