{ config, pkgs, ... }:

{
  imports = [ ./steam.nix ];

  environment.systemPackages = with pkgs; [
    discord
    mangohud gamemode goverlay
    prismlauncher
    openrct2
  ];
}
