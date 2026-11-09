{ config, pkgs, nixpkgs-master, ... }:

{
  environment.systemPackages = with pkgs; [
    sakura alacritty ghostty
    slack
    pulsar
    zoom-us
    libreoffice
    insomnia

    # trying out some SQL GUIs
    sequeler beekeeper-studio dbeaver-bin

    sql-formatter # node based command line sql format tool

    # nixpkgs puts gtk2 (marked broken ahead of its removal) in Horizon's FHS
    #  env, but the client only links GTK3, so leave it out
    (omnissa-horizon-client.override {
      buildFHSEnv = args: buildFHSEnv (args // {
        targetPkgs = p: builtins.filter (d: (d.pname or "") != "gtk+") (args.targetPkgs p);
      });
    })
  ];

  networking.firewall.allowedTCPPorts = [
    # default and common rails server ports:
    3000
    3111
    3222
    3333
  ];
}
