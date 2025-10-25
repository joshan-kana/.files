# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

{
  # Enable display manager
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = false;
  };

  # services.xserver.displayManager.sddm.enable = true;
  # services.xserver.displayManager.sddm.wayland.enable = true;

  # Configuring ZSH
  # Installing ZSH
  programs.zsh.enable = true;
  programs.zsh.enableBashCompletion = true;

  # Setting it as the default shell
  users.defaultUserShell = pkgs.zsh;

  # Setting up man pages for apropos and man -k
  documentation.man.generateCaches = true;

  # Enabling direnv
  programs.direnv = {
    enable = true;
    silent = true;
  };

  # Installing fonts
  # fonts.packages = with pkgs; [
  #  (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  # ];

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
      ovmf.enable = true;
      ovmf.packages = [ pkgs.OVMFFull.fd ];
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
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
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
    jetbrains.pycharm-professional
    floorp-bin
    libreoffice
    pavucontrol
    python3
    trash-cli
    nixpkgs-fmt
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
    swww
    networkmanagerapplet
    playerctl
    grimblast
    nwg-panel
    nwg-dock-hyprland
    nwg-displays
    wlr-randr
    tofi
    tmuxai
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:


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
  hardware.pulseaudio.enable = false;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 47990 11434 11435 ];
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
      experimental-features = [ "nix-command" "flakes" ];
      warn-dirty = false;
    };
  };

  # Stylix (colours)
  stylix.enable = true;
  stylix.image = ./wallpaper.png;
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
  stylix.fonts = {
    serif = config.stylix.fonts.monospace;
    sansSerif = config.stylix.fonts.monospace;
    monospace = {
      package = pkgs.nerd-fonts.monaspace;
      name = "MonaspiceNe Nerd Font Mono";
    };

    emoji = {
      package = pkgs.noto-fonts-emoji;
      name = "Noto Color Emoji";
    };
  };
  stylix.polarity = "dark";

  stylix.cursor.package = pkgs.google-cursor;
  stylix.cursor.name = "GoogleDot-Black";
  stylix.cursor.size = 30;
}
