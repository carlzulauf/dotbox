{ config, pkgs, ... }:

{
  imports = [
    ./gnome.nix
  ];

  # disable sleep on login screen
  services.displayManager.gdm.autoSuspend = false;

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
