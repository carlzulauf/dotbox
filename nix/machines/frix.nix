{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
let
  # necessary because otherwise builds with all arch and hits OOM errors
  rocmPkgs = nixpkgs-master.rocmPackages.overrideScope (_: rprev: {
    clr = rprev.clr.override { localGpuTargets = [ "gfx1151" ]; };
  });
in
{
  # Framework Desktop (Ryzen 9 395+ w/128GB RAM)
  networking.hostName = "frix";

  # keep unused wifi from rotating mac addresses, which trips up tailscaled
  networking.networkmanager.wifi = {
    macAddress = "permanent";
    scanRandMacAddress = false;
  };

  # extra bleeding edge kernel
  boot.kernelPackages = nixpkgs-master.linuxPackages_latest;

  imports =
    [
      nixos-hardware.nixosModules.common-pc-ssd
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/gnome-hidpi.nix
      ../includes/gnome-niri.nix
      ../includes/dev.nix
      ../includes/printing.nix
    ];

  environment.systemPackages = with pkgs; [
    discord wavemon prismlauncher
    nvtopPackages.amd
    virt-manager
    signal-cli
  ];

  # lsblk --output NAME,SIZE,TYPE,MOUNTPOINTS,UUID
  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/8bc680b4-1c64-49b9-8b21-fcf38e5f652e";
    fsType = "ext4";
  };

  # expose /mnt/backup/carl via /home/carl/backup through a bind mount
  fileSystems."/home/carl/backup" = {
    depends = [
        "/mnt/backup"
    ];
    device = "/mnt/backup/carl";
    fsType = "none";
    options = [
      "bind"
    ];
  };

  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };

  services.fwupd.enable = true;

  services.ollama = {
    package = nixpkgs-master.ollama-rocm.override {
      rocmPackages = rocmPkgs;
      rocmGpuTargets = [ "gfx1151" ];
    };
    rocmOverrideGfx = "11.5.1";
  };

  # trying out experimental gnome features
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/mutter" = {
          experimental-features = [
            "scale-monitor-framebuffer" # Enables fractional scaling (125% 150% 175%)
            "variable-refresh-rate" # Enables Variable Refresh Rate (VRR) on compatible displays
            "xwayland-native-scaling" # Scales Xwayland applications to look crisp on HiDPI screens
            "autoclose-xwayland" # automatically terminates Xwayland if all relevant X11 clients are gone
          ];
        };
      };
    }
  ];

  services.puma-dev = {
    enable = true;
    user = "carl";
  };

  time.timeZone = "America/Chicago";

  # using local models, so secrets don't need to be sops encrypted
  # environment.etc."hermes.yaml" = {
  #   text = "";
  #   mode = "0600";
  # };
  # services.hermes-agent = {
  #   enable = true;
  #   settings.model.base_url = "http://localhost:11434/api";
  #   settings.model.default = "gemma4:26b";
  #   environmentFiles = [ "/etc/hermes.yaml" ];
  #   addToSystemPackages = true;
  #   container = {
  #     image = "ubuntu:24.04";
  #     backend = "docker";
  #     hostUsers = [ "carl" ];
  #     extraVolumes = [ "/home/carl/projects:/projects:rw" ];
  #     extraOptions = [ "--gpus" "all" ];
  #   };
  # };

  # home-manager.users.carl = { ... }: {
  #   programs.openclaw = {
  #     enable = true;
  #     config = {
  #       gateway = {
  #         mode = "local";
  #         # Set OPENCLAW_GATEWAY_TOKEN env var, or put the token inline here:
  #         # auth.token = "your-token-here";
  #       };
  #       # Uncomment and configure a channel to interact with openclaw.
  #       # See https://github.com/openclaw/nix-openclaw for options.
  #       #
  #       # channels.telegram = {
  #       #   tokenFile = "/run/secrets/telegram-bot-token";
  #       #   allowFrom = [ 12345678 ]; # your Telegram user ID
  #       # };
  #     };
  #     bundledPlugins = {
  #       summarize.enable = true;
  #     };
  #   };
  # };

  # Define a user account for openclaw
  # users.users.clawdius = {
  #   isNormalUser = true;
  #   description = "Clawdius";
  #   extraGroups = [ "docker" ];
  #   packages = with pkgs; [
  #     # maybe add some user specific pkgs
  #   ];
  #   linger = true;
  # };

  # home-manager.users.clawdius = { ... }: {
  #   home.stateVersion = "24.11";
  #   programs.openclaw = {
  #     enable = true;
  #     config = {
  #       gateway = {
  #         mode = "local";
  #         # Set OPENCLAW_GATEWAY_TOKEN env var, or put the token inline here:
  #         # auth.token = "your-token-here";
  #       };
  #       # Uncomment and configure a channel to interact with openclaw.
  #       # See https://github.com/openclaw/nix-openclaw for options.
  #       #
  #       # channels.telegram = {
  #       #   tokenFile = "/run/secrets/telegram-bot-token";
  #       #   allowFrom = [ 12345678 ]; # your Telegram user ID
  #       # };
  #     };
  #     bundledPlugins = {
  #       summarize.enable = true;
  #     };
  #   };
  # };
}
