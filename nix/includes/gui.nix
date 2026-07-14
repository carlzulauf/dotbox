{ config, pkgs, nixpkgs-2605, home-manager, ... }:

{
  environment.systemPackages = with pkgs; [
    firefox firefox-devedition
    google-chrome chromium brave
    gimp inkscape
    signal-desktop
    # trying some matrix clients
    element-desktop fractal
    keepassxc
    # vlc handbrake audacity
    vlc nixpkgs-2605.handbrake audacity
    playerctl
    flatpak appimage-run
    ventoy
    cpu-x
  ];

  home-manager.users.carl = { ... }: {
    programs.vscodium = {
      enable = true;
      # Allow runtime installation of extensions, and give extensions like ruby-lsp a reasonable build environment
      package = pkgs.vscodium.fhsWithPackages (p: with p; [
        gcc gnumake
        libyaml
      ]);
      profiles.default = {
        extensions = with pkgs.vscode-extensions; [
          continue.continue
          jnoortheen.nix-ide
          # anthropic.claude-code
          shopify.ruby-lsp
          # BriteSnow.vscode-toggle-quotes # not supported for some reason
        ];
      };
    };
  };

  # maybe this will go away some day soon. wayland is pretty decent now.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

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
