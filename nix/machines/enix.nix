{ config, pkgs, nixos-hardware, nixpkgs-master, ... }:

{
  # HP Envy 2-in-1 w/5800U
  networking.hostName = "enix";

  # I'm a tablet
  hardware.sensor.iio.enable = true;
  # services.iio-niri = {
  #   enable = true;
  #   extraArgs = [
  #     "--monitor"
  #     "eDP-1"
  #   ];
  # };

  # hardware is old enough we can probably use an LTS kernel, but not today
  boot.kernelPackages = pkgs.linuxPackages_latest;

  imports =
    [
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-ssd
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/gui.nix
      ../includes/printing.nix
      ../includes/dictation.nix # Parakeet on the CPU
      ../includes/gnome.nix
      ../includes/gnome-cosmic.nix
      # not much of a gaming device, but will be used to stream games.
      # gets steam, but doesn't need the full gaming.nix
      ../includes/steam.nix
      # Synaptics 06cb:00e7 fingerprint sensor
      ../pkgs/synaptics-00e7/module.nix
    ];

  environment.systemPackages = with pkgs; [
    ryzenadj
    discord
    wavemon # ncurses wifi monitor
    slack zoom-us
  ];

  services.fwupd.enable = true;

  # programs.hyprland.enable = true;
  # programs.iio-hyprland.enable = true;
  # services.hypridle.enable = true;
  # programs.hyprlock.enable = true;

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "24.05";
}
