# Standalone niri desktop, riced with DankMaterialShell (DMS). DMS is a single
# Quickshell shell covering what a bare niri setup assembles from separate
# tools (waybar, fuzzel, mako, swaylock, swayidle, cliphist, a polkit agent,
# OSDs), and themes all of it from the wallpaper with matugen. Its greeter
# (greetd, running in niri) replaces GDM.
#
# Unlike gnome-niri.nix this doesn't expect GNOME alongside it, and it can't
# be combined with gnome.nix (two display managers).
#
# niri's config isn't generated here: it's user-owned, and DMS rewrites its
# includes at runtime (colors, outputs, binds from its settings UI). The first
# niri session deploys DMS's stock config into ~/.config/niri instead, and
# deleting ~/.config/niri/config.kdl gets a fresh copy at the next login.
#
# Keys worth knowing (DMS's defaults, Mod = Super):
#   Mod+Shift+/  every keybind      Mod+T      terminal (ghostty)
#   Mod+Space    app launcher       Mod+V      clipboard history
#   Mod+Comma    DMS settings       Mod+Y      wallpapers (re-themes everything)
#   Mod+N        notifications      Mod+Alt+L  lock
#   Mod+O/Tab    overview           Super+X    power menu
{ config, lib, pkgs, ... }:
let
  user = "carl";
  dms = lib.getExe' config.programs.dms-shell.package "dms";
in
{
  programs.niri.enable = true;
  programs.dms-shell.enable = true;

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    # Copies the user's DMS theme and wallpaper so the greeter matches it.
    configHome = config.users.users.${user}.home;
  };

  # The niri module turns on gnome-keyring; unlock it with the login password.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # DMS's lock screen authenticates against /etc/pam.d/dankshell when it
  # exists, and otherwise falls back to a PAM file it ships, which names
  # modules by FHS paths NixOS doesn't have.
  security.pam.services.dankshell = { };

  # niri-session starts niri.service, so this runs before every niri session
  # and does nothing once a config exists. Same as running `dms setup` and
  # picking niri, minus the prompts.
  systemd.user.services.niri-dms-config = {
    description = "Deploy DankMaterialShell's niri config";
    wantedBy = [ "niri.service" ];
    before = [ "niri.service" ];
    unitConfig.ConditionPathExists = "!%h/.config/niri/config.kdl";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${dms} setup headless --compositor niri --skip-existing";
    };
  };

  # Electron/Chromium apps on Wayland instead of Xwayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # qt5ct/qt6ct pick up the Qt color scheme DMS generates from the wallpaper.
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  # Trash, removable drives and network locations in nautilus.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  environment.systemPackages = with pkgs; [
    ghostty            # terminal; DMS binds it to Mod+T
    nautilus           # file manager, and the portal's file chooser
    xwayland-satellite # niri runs X11 apps through this when it's on PATH
    adw-gtk3           # libadwaita look for GTK3 apps, recolored by DMS
    papirus-icon-theme
    pavucontrol
  ];
}
