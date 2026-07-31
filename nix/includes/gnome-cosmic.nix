# This cosmic config is expected to live alongside gnome and use GDM.
# It may work elsewhere, but the assumption is there will be problems.
{ config, lib, pkgs, ... }:

{
  # --- Cosmic Desktop (alongside GNOME, selectable at GDM) ---
  services.desktopManager.cosmic = {
    enable = true;
  };

  # This is supposed to improve performance, but should be tested
  # services.system76-scheduler.enable = true;

  # bypass wayland clipboard authoritarianism
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = 1;

  environment.systemPackages = with pkgs; [
    cosmic-ext-applet-caffeine
  ];
}
