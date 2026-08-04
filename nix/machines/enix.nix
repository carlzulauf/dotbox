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
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/gui.nix
      ../includes/printing.nix
      ../includes/gnome.nix
      ../includes/gnome-cosmic.nix
    ];

  environment.systemPackages = with pkgs; [
    ryzenadj
    discord
    wavemon # ncurses wifi monitor
    slack zoom-us
  ];

  services.fwupd.enable = true;

  # Tried these, fingerprint sensor still doesn't work
  #   services.fprintd.enable = true;
  #   services.fprintd.tod.enable = true;
  #   services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix;
  #   services.fprintd.tod.driver = pkgs.libfprint-2-tod1-elan;

  # programs.hyprland.enable = true;
  # programs.iio-hyprland.enable = true;
  # services.hypridle.enable = true;
  # programs.hyprlock.enable = true;
  time.timeZone = "America/Chicago";
}
