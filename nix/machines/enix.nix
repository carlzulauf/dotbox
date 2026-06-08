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
      ../includes/gnome.nix
      ../includes/gnome-niri.nix
      ../includes/dev.nix
      ../includes/printing.nix
    ];

  environment.systemPackages = with pkgs; [
    ryzenadj
    discord
    wavemon # ncurses wifi monitor
    prismlauncher # minecraft
    iio-niri # manually started by niri config

    nixpkgs-master.claude-code
    nixpkgs-master.opencode
    nixpkgs-master.pi-coding-agent
  ];

  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };

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
