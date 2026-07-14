{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    transmission_4-gtk
    gnome-secrets eog gnome-boxes gnome-sound-recorder gnome-music
    gnome-firmware gnome-tweaks dconf-editor
    gnome-themes-extra pop-gtk-theme
    packagekit

    gnomeExtensions.appindicator
    gnomeExtensions.caffeine
    gnomeExtensions.desktop-cube
    gnomeExtensions.freon
    gnomeExtensions.screen-rotate
    gnomeExtensions.clipboard-history
    gnomeExtensions.desktop-cube
    gnomeExtensions.paperwm

    gparted resources
    # pavucontrol crashes with Pop theme; wrapping with GTK_THEME=Adwaita:dark fixes it
    (pavucontrol.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.makeWrapper ];
      postInstall = (old.postInstall or "") + ''
        wrapProgram $out/bin/pavucontrol \
          --set GTK_THEME "Adwaita:dark"
      '';
    }))
    # gnome-session gnome-remote-desktop
    # xdg-desktop-portal xdg-desktop-portal-gnome

    solaar # logitech control
    deskflow # open source synergy w/wayland support
  ];

  # if I'm using gnome, I want to support my peripherials I guess
  hardware.logitech.wireless.enable = true;

  # open port for deskflow server
  networking.firewall.allowedTCPPorts = [ 24800 ];

  services = {
    # Enable GDM display manager, the preferred one for GNOME
    displayManager.gdm = {
      enable = true;
      autoSuspend = false;
    };
    # Enable the GNOME Desktop Environment.
    desktopManager.gnome = {
      enable = true;
      # extraGSettingsOverridePackages = [ pkgs.mutter ];
      # extraGSettingsOverrides = ''
      #   [org.gnome.mutter]
      #   experimental-features=['scale-monitor-framebuffer']
      # '';
    };
  };

  # Configure GNOME
  services.gnome.games.enable = true;
  # services.gnome.gnome-remote-desktop.enable = true;

  # services.xrdp = {
  #   enable = true;
  #   openFirewall = true;
  #   defaultWindowManager = "gnome-session";
  # };

  programs.gnome-terminal.enable = true;

  # Prevent GDM (gnome display manager) login from timing out and suspending
  # verity with:
  #  $ gsettings list-recursively org.gnome.settings-daemon.plugins.power
  # programs.dconf.profiles.gdm.databases = [{
  #  settings."org/gnome/settings-daemon/plugins/power" = {
  #    sleep-inactive-ac-type = "nothing";
  #    sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
  #  };
  #}];

  services.qemuGuest.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
    # config.common.default = "*";
  };

  /* disabled due to libpeas-2.0.1 build error (lua51 missing) */
  /* services.gnome.core-developer-tools.enable = true; */

  # desktop applications list: ll /run/current-system/sw/share/applications/
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "text/plain" = "org.gnome.TextEditor.desktop";

    "application/pdf" = "org.gnome.Evince.desktop";
    "application/ogg" = "vlc.desktop";
    "application/x-ogg" = "vlc.desktop";
    "application/rdf+xml" = "org.gnome.TextEditor.desktop";
    "application/rss+xml" = "org.gnome.TextEditor.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "application/xhtml_xml" = "firefox.desktop";
    "application/xml" = "org.gnome.TextEditor.desktop";

    "image/jpeg" = "org.gnome.eog.desktop";
    "image/png" = "org.gnome.eog.desktop";
    "image/tiff" = "org.gnome.eog.desktop";
    "image/gif" = "org.gnome.eog.desktop";
    "image/svg+xml" = "org.gnome.eog.desktop";
    "image/svg+xml-compressed" = "org.gnome.eog.desktop";

    "audio/ac3" = "vlc.desktop";
    "audio/mp4" = "vlc.desktop";
    "audio/mpeg" = "vlc.desktop";
    "audio/ogg" = "vlc.desktop";
    "audio/x-flac" = "vlc.desktop";
    "audio/x-matroska" = "vlc.desktop";
    "audio/x-mp2" = "vlc.desktop";
    "audio/x-mp3" = "vlc.desktop";
    "audio/x-mpeg" = "vlc.desktop";
    "audio/x-vorbis" = "vlc.desktop";

    "video/mp4" = "vlc.desktop";
    "video/mpeg" = "vlc.desktop";
    "video/x-matroska" = "vlc.desktop";
    "video/ogg" = "vlc.desktop";
    "video/vnd.divx" = "vlc.desktop";

    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };
}
