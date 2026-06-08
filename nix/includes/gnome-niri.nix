# This niri config is expected to live alongside gnome and use GDM.
# It may work elsewhere, but the assumption is there will be problems.
{ config, lib, pkgs, ... }:

{
  # --- Niri (alongside GNOME, selectable at GDM) ---
  programs.niri.enable = true;
  programs.xwayland.enable = true;

  # PAM entry for swaylock (not provided by nixpkgs niri module)
  security.pam.services.swaylock = {};

  fonts.packages = with pkgs; [ noto-fonts font-awesome ];

  services.libinput.enable = true;

  # IBus autostart fires in Niri (NotShowIn=GNOME;KDE; doesn't exclude it).
  # /etc/xdg is first in $XDG_CONFIG_DIRS so this override wins.
  environment.etc."xdg/autostart/ibus-daemon.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

  environment.systemPackages = with pkgs; [
  # --- Niri-specific GUI tools ---
    fuzzel           # Wayland launcher
    kitty            # GPU-accelerated terminal
    waybar
    mako             # Wayland notifications
    grim slurp       # Screenshots
    wlr-randr        # Monitor management
    brightnessctl
    swaylock
    swaybg
    xwayland-satellite
  ];
}
