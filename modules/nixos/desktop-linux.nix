{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./boot.nix
    ./ssh.nix
    ./vpn.nix
    ../../desktop/display-manager.nix
    ../../desktop/hyprland/hyprland_nixos.nix
    ../../desktop/plasma/plasma.nix
  ];

  config = lib.mkIf config.dotfiles.features.desktop.enable {
    services.xserver = {
      enable = true;
      displayManager.lightdm.enable = false;
      xkb = {
        layout = "us";
        variant = "";
      };
    };

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
      WLR_NO_HARDWARE_CURSORS = "1";
      KWIN_FORCE_SW_CURSOR = "1";
      NIXOS_OZONE_WL = "1";
      EDITOR = "nvim";
    };

    virtualisation.docker.enable = true;
    users.users.${config.dotfiles.users.primary.name}.extraGroups = [
      "docker"
      "libvirtd"
    ];
    virtualisation.libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };
    programs.virt-manager.enable = true;
    security.polkit.enable = true;
    services.gvfs.enable = true;

    boot.binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };

    boot.kernelPackages = pkgs.linuxPackages_latest;
    security.pam.services.swaylock = { };
    boot.loader.efi.canTouchEfiVariables = true;
    boot.plymouth.enable = false;

    environment.systemPackages = with pkgs; [
      chromium
      waypipe
      sunshine
      mpv
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
      mullvad-vpn
      github-desktop
      nautilus
      vlc
      youtube-tui
      brightnessctl
      jetbrains.pycharm
      libreoffice
      pavucontrol
      python3
      trash-cli
      gnumake
      devbox
      has
      waybar
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

    programs.yazi.enable = true;

    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
    services.pulseaudio.enable = false;

    networking.firewall.allowedTCPPorts = [
      22
      47990
      11434
      11435
    ];
  };
}
