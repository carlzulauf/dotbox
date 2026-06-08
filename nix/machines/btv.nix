{ config, pkgs, nixos-hardware, ... }:

{
  # Geekom Intel N100 mini pc for Bird's TV
  # 12GB soldered RAM, 512GB SATA SSD
  networking.hostName = "btv";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-intel
      nixos-hardware.nixosModules.common-gpu-intel
      ../includes/gui.nix
      ../includes/tv.nix
      ../includes/printing.nix
    ];

  # nix.settings.substituters = [ "http://nax/" ];

  # environment.systemPackages = with pkgs; [ ];
  time.timeZone = "America/Chicago";
}
