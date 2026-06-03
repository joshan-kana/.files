# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  inputs,
  dotfilesPath,
  ...
}:

{
  # Enable display manager
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = false;
  };

  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.displayManager.sddm.wayland.enable = true;

  # nh: yet another cli helper for nh
  # to activate config with nh: sudo nh os switch --hostname <profile-name> --impure
  programs.nh = {
    enable = true;
    flake = dotfilesPath;
  };

  # Configuring ZSH
  # Installing ZSH
  programs.zsh.enable = true;
  programs.zsh.enableBashCompletion = true;

  # Setting it as the default shell
  users.defaultUserShell = pkgs.zsh;

  # Setting up man pages for apropos and man -k

  documentation = {
    enable = true;
    man = {
      enable = true;
      cache.enable = true;
    };
  };

  # Enabling direnv
  programs.direnv = {
    enable = true;
    silent = true;
    enableZshIntegration = false;
  };

  # Installing fonts
  # Fixes mismatched glyph sizing by ensuring icon/PUA glyphs resolve to a
  # dedicated Nerd Font symbols face instead of an arbitrary fallback.
  fonts =
    let
      nerdSymbols =
        if builtins.hasAttr "nerd-fonts" pkgs then
          pkgs."nerd-fonts".symbols-only
        else
          (pkgs.nerdfonts.override { fonts = [ "NerdFontsSymbolsOnly" ]; });
    in
    {
      packages = [
        config.stylix.fonts.monospace.package
        config.stylix.fonts.emoji.package
        nerdSymbols
      ];

      fontconfig.defaultFonts = {
        monospace = [
          config.stylix.fonts.monospace.name
          "Symbols Nerd Font Mono"
          "Symbols Nerd Font"
        ];
        sansSerif = [ config.stylix.fonts.sansSerif.name ];
        serif = [ config.stylix.fonts.serif.name ];
        emoji = [ config.stylix.fonts.emoji.name ];
      };
    };

  environment.sessionVariables = {

    # invisible cursor fix
    WLR_NO_HARDWARE_CURSORS = "1";

    # invisible cursor fix (KDE Plasma)
    KWIN_FORCE_SW_CURSOR = "1";

    # hint at electron apps to use wayland
    NIXOS_OZONE_WL = "1";

    # Setting the default editor
    EDITOR = "nvim";

    # Start Hyprland on Nvidia
    # WLR_DRM_DEVICES = "/dev/dri/card1";
  };

  # Docker
  virtualisation.docker = {
    enable = true;
  };

  # Virtualisation
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;

  # Config for nixos-rebuild build-vm
  virtualisation.vmVariant = {
    virtualisation = {
      cores = 4;
      memorySize = 8192;
    };
  };

  # Polkit
  security.polkit.enable = true;

  # Dependency for ags mpris
  services.gvfs.enable = true;

  # Set linux kernel to use to following interpreter for app images
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  # Setting the linux kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Settings for swaylock to work
  security.pam.services.swaylock = { };

  # Bootloader.
  boot.loader.efi.canTouchEfiVariables = true;

  # Use boot animation
  boot.plymouth.enable = false;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Australia/Perth";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  # Configure keymap in X11
  services.xserver = {
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.joshan = {
    isNormalUser = true;
    description = "Joshan Kana";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
    ];
    packages = with pkgs; [ ];
    initialPassword = "test";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    lf
    chromium
    waypipe
    sunshine
    lshw
    fastfetch
    mpv
    home-manager
    thunderbird
    obsidian
    kdePackages.filelight
    gimp
    stow
    qjackctl
    xdg-utils
    wl-clipboard
    quickemu
    killall
    gparted
    moonlight-qt
    distrobox
    bottles
    tree
    mullvad-vpn
    github-desktop
    nautilus
    vlc
    youtube-tui
    glow
    # ulauncher # disable until nixpkgs updates after v5.15.7
    brightnessctl
    jetbrains.pycharm
    libreoffice
    pavucontrol
    python3
    trash-cli
    nixfmt
    gnumake
    devbox
    has
    # upscayl
    # davinci-resolve

    # window manager stuff
    waybar
    #mako
    #libnotify
    polkit_gnome
    awww
    networkmanagerapplet
    playerctl
    grimblast
    nwg-panel
    nwg-dock-hyprland
    nwg-displays
    wlr-randr
    tofi
    tmuxai
    nvd
    nix-tree
    gh
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  # yazi: TUI file manager
  programs.yazi = {
    enable = true;
  };

  # Enabling sound
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Disabling pulseaudio (for assertion)
  services.pulseaudio.enable = false;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    22
    47990
    11434
    11435
  ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  nix = {
    settings = {
      trusted-users = [ "joshan" ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
      # Use binary caches as much as possible.
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      require-sigs = true;
      # If a binary isn't available, fail fast instead of building locally.
      fallback = false;
      # If you later add remote builders, still allow them to substitute.
      builders-use-substitutes = true;
    };
  };

  # Stylix (colours)
  stylix = {
    enable = true;
    image = ./wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/framer.yaml";
    fonts = {
      serif = config.stylix.fonts.monospace;
      sansSerif = config.stylix.fonts.monospace;
      monospace = {
        package = pkgs.monaspace-liga;
        name = "Monaspace Neon";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
    polarity = "dark";
    cursor = {
      package = pkgs.google-cursor;
      name = "GoogleDot-Black";
      size = 30;
    };
  };
}
