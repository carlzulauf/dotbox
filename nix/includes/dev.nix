{ config, pkgs, nixpkgs-master, nixpkgs-pinned, ... }:

{
  environment.systemPackages = with pkgs; [
    sakura alacritty ghostty
    slack
    # patchelf 0.19 trips a `splitIndex == -1` assertion setting the rpath a
    #  second time on resources/app/ppm/bin/node; 0.15 from the pin handles it
    (pulsar.overrideAttrs (old: {
      preFixup = "PATH=${nixpkgs-pinned.patchelf}/bin:$PATH\n" + old.preFixup;
    }))
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
