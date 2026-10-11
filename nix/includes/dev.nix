{ config, pkgs, nixpkgs-master, ... }:

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
  ];

  networking.firewall.allowedTCPPorts = [
    # default and common rails server ports:
    3000
    3111
    3222
    3333
  ];
}
