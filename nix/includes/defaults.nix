{ config, pkgs, nixpkgs-master, ... }:
let
  # pinnedRuby = import (builtins.fetchTarball {
  #   url = "https://github.com/NixOS/nixpkgs/archive/83e1ebb0c67cb310adeeabf6c4ab6218dbad403d.tar.gz";
  #   sha256 = "sha256:1ihv7xxqg9irc1kimnhdyspa7ckfw73646r36008v3d2c3a2q1bs";
  # }) {
  #   system = "x86_64-linux";
  # };
in
{
  nixpkgs.config = {
    allowUnfree = true;
    allowInsecurePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
      "pulsar"
      "electron"
      "deskflow"
      "beekeeper-studio"
      "ventoy"
      "mbedtls"
      "openclaw"
    ];
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "ntfs" ];

  # Enable fish and make it the default shell everywhere
  programs.fish.enable = true;
  users.defaultUserShell = pkgs.fish;
  # clear out fish aliases so they don't override my dotbox fish config
  programs.fish.shellAliases = {
    l = null;
    ll = null;
    ls = null;
  };

  # specifying timezone appears to disable automatic timezone adjustment
  # time.timeZone = "America/Denver";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    kpcli # keepass CLI
    lm_sensors smartmontools pciutils
    btrfs-progs wireguard-tools
    micro git gh
    fish eza file fzf starship direnv tldr
    wget curl dig sshfs
    nethogs nmap whois ethtool iw
    dysk ncdu yazi inotify-tools psmisc
    btop htop fastfetch
    ffmpeg imagemagick
    sops age
    sqlite jq yq lbzip2 p7zip cdrtools
    (ruby_4_0.withPackages (ps: with ps; [
      pry ruby-lsp
    ]))
    gcc gnumake pkg-config libyaml.dev
    python3
    nodejs

    syncthing tailscale

    docker-compose
    distrobox
    terraform
  ];

  # nix-ld provides /lib64/ld-linux-x86-64.so.2, letting FHS-compiled binaries
  # (e.g. native gem .so files built inside vscodium.fhs) run in the regular environment
  programs.nix-ld.enable = true;

  # Expose pkg-config files from all system packages so native gem compilation works
  environment.pathsToLink = [ "/lib/pkgconfig" ];

  environment.variables = rec {
    EDITOR = "micro";

    # move ruby gems and add executables to PATH
    NIX_GEM_HOME = "$HOME/.local/share/gems/nix";
    NIX_GEM_BIN = "${NIX_GEM_HOME}/bin";
    GEM_HOME = "${NIX_GEM_HOME}";

    # redirect npm global installs away from read-only nix store
    NPM_CONFIG_PREFIX = "$HOME/.npm-global-nix";

    PKG_CONFIG_PATH = "/run/current-system/sw/lib/pkgconfig";

    PATH = [ "${NIX_GEM_BIN}" "${NPM_CONFIG_PREFIX}/bin" ];
  };

  # Output list of system packages for the current generation to:
  #  /etc/current-system-packages
  environment.etc."current-system-packages".text =
    let
      packages = builtins.map (p: "${p.name}") config.environment.systemPackages;
      sortedUnique = builtins.sort builtins.lessThan (pkgs.lib.lists.unique packages);
    in
      builtins.concatStringsSep "\n" sortedUnique;

  networking.networkmanager.enable = true;
  # needed to make wireguard connections work:
  networking.firewall.checkReversePath = "loose";
  # needed for tailscale to work, and probably better
  services.resolved.enable = true;
  # Nix daemon config
  nix = {
    # Automate garbage collection
    # gc = {
    #   automatic = true;
    #   dates = "weekly";
    #   options = "--delete-older-than 7d";
    # };

    settings = {
      # Automate `nix store --optimise`
      auto-optimise-store = true;

      # enable flakes, permanently
      experimental-features = [ "nix-command" "flakes" ];

      # allow carl to use substituters from flakes (e.g. cache.numtide.com)
      trusted-users = [ "root" "carl" ];
    };
  };

  services.tailscale = {
    enable = true;
    #package = nixpkgs-master.tailscale;
    useRoutingFeatures = "both";
  };

  # turn on openssh server with sane settings
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # fix legacy distrobox containers which expect /sys/fs/selinux
  security.lsm = pkgs.lib.mkForce [ ];

  # configure podman
  virtualisation.podman.enable = true;
  # virtualisation.podman.dockerCompat = true; # basically, podman-docker

  # configure docker
  # enable rootless mode
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    # daemon.settings.dns = [ "100.100.100.100" ];
  };
}
