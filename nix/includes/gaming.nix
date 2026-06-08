{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    discord
    mangohud goverlay
    # heroic lutris # breaking 2026/04/25
    prismlauncher
  ];

  # additional steam setup
  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
  programs.gamescope.enable = true;
}
