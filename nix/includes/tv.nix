{ config, lib, pkgs, ... }:

{
  imports = [
    ./gnome.nix
  ];

  # disable sleep on login screen
  services.displayManager.gdm.autoSuspend = false;

  # TV boxes drive an HDMI display that gets powered off / switched away at the
  # TV. When GNOME idle-blanks the output it puts the connector into DPMS off,
  # and mutter fails to re-arm it when the TV/input comes back (input activity
  # no longer wakes it) - the screen stays black until the session restarts.
  # Disabling idle blanking / suspend entirely avoids the broken state: the
  # HDMI output never goes into power-save, so it always follows the TV.
  #
  # To recover a stuck display live without a rebuild:
  #   gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
  #     --object-path /org/gnome/Mutter/DisplayConfig \
  #     --method org.freedesktop.DBus.Properties.Set \
  #     org.gnome.Mutter.DisplayConfig PowerSaveMode "<int32 0>"
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        # never blank the screen on idle (this is what triggers DPMS off)
        "org/gnome/desktop/session" = {
          idle-delay = lib.gvariant.mkUint32 0;
        };
        # never auto-suspend or dim on AC power
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
          idle-dim = false;
        };
        # don't activate the screensaver / lock (which also blanks)
        "org/gnome/desktop/screensaver" = {
          idle-activation-enabled = false;
          lock-enabled = false;
        };
      };
    }
  ];

  # web ui for machine admin
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };
}
