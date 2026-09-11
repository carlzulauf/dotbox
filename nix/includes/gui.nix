{ config, pkgs, lib, ... }:

{
  # RDP between machines over the tailnet; picks GNOME or Plasma backends itself
  imports = [ ./remote-desktop.nix ];

  environment.systemPackages = with pkgs; [
    firefox firefox-devedition
    google-chrome chromium brave
    gimp inkscape
    signal-desktop
    keepassxc
    vlc audacity
    playerctl
    wl-clipboard # wl-copy/wl-paste: lets micro & other TUIs use the system clipboard
    flatpak appimage-run
    ventoy
    cpu-x
    (vscode-with-extensions.override {
      vscode = vscodium;
      vscodeExtensions = with vscode-extensions; [
        continue.continue
        jnoortheen.nix-ide
        shopify.ruby-lsp
        stkb.rewrap
      ];
    })
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  gtk.iconCache.enable = true;
  programs.ssh.enableAskPassword = true; # SSH_ASKPASS for GUI passphrase prompts
  programs.ssh.setXAuthLocation = true; # XAuthLocation, for `ssh -X`

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  services.flatpak.enable = true;

  # update timezone based on location guess
  # this is proving to be flaky, at least on XPS
  # services.automatic-timezoned.enable = true;
}
