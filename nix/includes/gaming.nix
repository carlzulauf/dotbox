{ config, pkgs, nixpkgs-master, ... }:

{
  environment.systemPackages = with pkgs; [
    discord
    mangohud gamemode
    heroic lutris
    prismlauncher
    openrct2
  ] ++ [
    nixpkgs-master.goverlay # unstable's lazarus broken 2026-10-02, fixed in master
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
