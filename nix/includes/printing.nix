{ config, pkgs, ... }:

{
  # specifically configures necessary components to talk to networked brother laser printer
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.brlaser ];
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
