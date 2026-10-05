{ config, pkgs, lib, nixpkgs-master, ... }:
let
  # pinnedRuby = import (builtins.fetchTarball {
  #   url = "https://github.com/NixOS/nixpkgs/archive/83e1ebb0c67cb310adeeabf6c4ab6218dbad403d.tar.gz";
  #   sha256 = "sha256:1ihv7xxqg9irc1kimnhdyspa7ckfw73646r36008v3d2c3a2q1bs";
  # }) {
  #   system = "x86_64-linux";
  # };

  # nix-direnv 3.2.0 misbehaves when several tmux windows load the same
  # flake-based .envrc at once, so stay on 3.1.2 (latest 3.1.x) until that's
  # fixed upstream. resholve builds nix-direnv in two stages, so the older
  # source has to be swapped into the inner (unresholved) derivation as well as
  # the outer one, otherwise only the resholve wrapper gets downgraded.
  useNixDirenv312 = drv: drv.overrideAttrs (_: {
    version = "3.1.2";
    src = pkgs.fetchFromGitHub {
      owner = "nix-community";
      repo = "nix-direnv";
      rev = "3.1.2";
      hash = "sha256-3qT5mSqHi+0cskdoOGPVbuSzkoWtwOHBVXUOL84dAM8=";
    };
  });
  # matches the module default, which builds against the system's nix
  nixDirenv = pkgs.nix-direnv.override { nix = config.nix.package; };
  nixDirenvPinned = (useNixDirenv312 nixDirenv).overrideAttrs (_: {
    src = useNixDirenv312 nixDirenv.unresholved;
  });

  # environment.enableAllTerminfo = true is the one-liner version of this, but it
  # force-builds every terminal in its list, so one broken terminal blocks the
  # rebuild of every machine. The gcc 16 switch in nixpkgs broke two of them:
  #
  #   rxvt-unicode 9.31 - rxvtutil.h defines its own lerp() template, now
  #     ambiguous against C++20's std::lerp, so rxvttoolkit.C won't compile.
  #   contour           - Image.cpp uses std::experimental::simd, which gcc 16
  #     no longer ships.
  #
  # Neither is fixed upstream and nothing here uses either terminal, so install
  # the module's list (nixos/modules/config/terminfo.nix) minus those two. Go back
  # to `environment.enableAllTerminfo = true` once they compile again.
  #
  # For now, this list has been trimmed to terminals I actually use or am likely
  # to encounter.
  terminfoPackages = map (p: p.terminfo) (with pkgs.pkgsBuildBuild; [
    alacritty
    foot
    ghostty
    kitty
    tmux
  ]);

  # Bounded stand-in for micro's wl-clipboard calls, which hang forever when
  # the compositor can't hand out focus (e.g. ssh'd into a locked session).
  microClip = pkgs.writeShellApplication {
    name = "micro-clip";
    runtimeInputs = with pkgs; [ coreutils wl-clipboard systemd ];
    text = builtins.readFile ./micro-clip.sh;
  };
in
{
  config = {
    nixpkgs.config = {
      allowUnfree = true;
      allowInsecurePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
        "pulsar"
        "electron"
        "deskflow"
        "beekeeper-studio"
        "ventoy"
        "mbedtls"
      ];
    };

    # Bootloader.
    boot.loader.systemd-boot = {
      enable = true;
      memtest86.enable = true;
      edk2-uefi-shell.enable = true;
      configurationLimit = lib.mkDefault 5; # some machines have bigger /boot
    };
    boot.initrd.systemd.emergencyAccess = true;
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
      nano micro microClip vim
      git git-absorb lazygit tig gh
      tmux fish
      eza file fzf starship tldr
      wget curl dig sshfs yt-dlp
      nethogs nmap whois ethtool iw
      dysk ncdu yazi inotify-tools psmisc
      btop htop fastfetch
      ffmpeg imagemagick
      sops age
      sqlite jq yq lbzip2 p7zip cdrtools
      gcc gnumake pkg-config libyaml.dev
      python3
      nodejs
      ruby_4_0

      syncthing tailscale

      docker-compose
      distrobox
      terraform

      nixpkgs-master.claude-code
      # nixpkgs-master.opencode
      nixpkgs-master.pi-coding-agent
      nixpkgs-master.agent-browser
    ]
    # terminfo for ghostty/kitty/foot/etc so remote tmux sessions work
    ++ terminfoPackages;

    programs.direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv = {
        enable = true;
        package = nixDirenvPinned;
      };
    };

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

      # Keep /usr/bin in the session PATH so flatpak apps work. glycin (GTK4 image
      # loading, used by most modern flatpaks) spawns its loaders via
      # `flatpak-spawn --sandbox`, wrapping them in a bare `prlimit` call. The
      # nested sandbox inherits the launcher's PATH; on NixOS that PATH normally
      # lacks /usr/bin, so `prlimit` (only present at the runtime's /usr/bin) can't
      # be exec'd and image loads die with "Loader process exited early with
      # status 1" (e.g. Sober/org.vinegarhq.Sober crashing on startup). Inside the
      # sandbox /usr/bin resolves to the runtime; on the host it just holds `env`.
      PATH = [ "${NIX_GEM_BIN}" "${NPM_CONFIG_PREFIX}/bin" "/usr/bin" ];
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

    # NixOS doesn't ship with this config, so Gnome labels connections with "?"
    # since they can't be verified. Adding this configuration and pointing at a
    # URL I control allows this question mark to go away if I can connect to the
    # broader internet and my main server is up and DNS works, so seeing a "?"
    # will represent a real problem connecting to my distributed network that I
    # should investigate.
    networking.networkmanager.settings.connectivity = {
      uri = "https://exalog.mrks.io/network_manager_check";
      response = "NetworkManager is online";
    };
    networking.firewall = {
      # needed to make wireguard connections work:
      checkReversePath = "loose";
      # trust everything on our tailnet, for science:
      trustedInterfaces = [ "tailscale0" ];
    };

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
      openFirewall = true; # allow tailscale UDP so direct connections are fast
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
  };
}
