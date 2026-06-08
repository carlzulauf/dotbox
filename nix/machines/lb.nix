{ config, pkgs, nixos-hardware, ... }:

{
  # Lenovo IdeaPad 14 w/Ryzen 4700u, 16GB RAM (soldered), 512GB SSD
  networking.hostName = "lb";

  imports =
    [
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-ssd
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/gaming.nix
      ../includes/printing.nix
    ];

  users.users.zintkala = {
    isNormalUser = true;
    description = "Zintkala Chikala";
    extraGroups = [ "networkmanager" "video" "wheel" "docker" "libvirtd" ];
    packages = with pkgs; [
      # maybe add some user specific pkgs
    ];
    shell = pkgs.fish;
    linger = true;
  };

  # environment.systemPackages = with pkgs; [ ];
}
