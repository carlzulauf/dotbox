{ config, pkgs, nixpkgs-master, ... }:
let
  # # Return to zoom-us package after this PR Is merged: https://github.com/NixOS/nixpkgs/pull/397036
  # fhsZoomPkgs = import (builtins.fetchTarball {
  #     url = "https://github.com/Yarny0/nixpkgs/archive/zoom-fhs.tar.gz";
  #     sha256 = "1pn0nm56sbcjd164g9cprvhg31ixc3nbjrz7gwpbrcdxynbjypg4";
  # }) {
  #   system = "x86_64-linux";
  #   config.allowUnfree = true;
  # };
in
{
  environment.systemPackages = with pkgs; [
    sakura alacritty ghostty
    pulsar slack
    zoom-us
    libreoffice
    insomnia

    # trying out some SQL GUIs
    sequeler beekeeper-studio dbeaver-bin

    sql-formatter # node based command line sql format tool

    omnissa-horizon-client
    # devenv # supposed to be magic: https://devenv.sh
  ];
}
