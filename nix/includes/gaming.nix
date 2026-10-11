{ config, pkgs, nixpkgs-master, ... }:

{
  imports = [ ./steam.nix ];

  environment.systemPackages = with pkgs; [
    discord
    mangohud gamemode
    heroic lutris
    prismlauncher
    openrct2
  ] ++ [
    nixpkgs-master.goverlay # unstable's lazarus broken 2026-10-02, fixed in master
  ];
}
