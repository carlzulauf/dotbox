{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
let
  # necessary because otherwise builds with all arch and hits OOM errors
  rocmPkgs = nixpkgs-master.rocmPackages.overrideScope (_: rprev: {
    clr = rprev.clr.override { localGpuTargets = [ "gfx1151" ]; };
  });

  ds4User = "carl";
  ds4Home = "/home/${ds4User}/.local/ds4";
  ds4Model = "${ds4Home}/gguf/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix-0731.gguf";
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
      ../includes/gnome-cosmic.nix
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

  # Keep ollama + open-webui installed and configured, but don't autostart them:
  # they compete with ds4 for the single shared RAM/GPU pool. Start on demand
  # with `systemctl start ollama` / `systemctl start open-webui`.
  systemd.services.ollama.wantedBy = lib.mkForce [ ];
  systemd.services.open-webui.wantedBy = lib.mkForce [ ];

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

  services.ds4 = {
    enable = true;
    user = ds4User;
    rocmPackages = nixpkgs-master.rocmPackages;
  };

  # ds4-server as a manually managed unit: `systemctl start|stop ds4`.
  # Like ollama/open-webui above it never autostarts — the ~80 GiB model plus
  # ROCm overhead leaves only ~16 GiB headroom, so only one runner at a time.
  #
  # Settings rationale (measured on this box at ctx=262144: KV 3.72 GiB +
  # buffers 2.00 GiB + model 80.76 GiB):
  #   --ctx 393216            Think Max is gated at exactly this context; below
  #                           it reasoning_effort=max silently drops to high.
  #                           Costs ~+2.7 GiB over 262144 (V4's compressed
  #                           attention makes context cheap).
  #   --kv-disk-space-mb      8192 filled up and evicted constantly; there are
  #                           2 TB free on this disk and it costs no RAM.
  #   --kv-cache-cold-max-tokens
  #                           default 30000 means cold prompts past 30k tokens
  #                           are never checkpointed at all, which is most of
  #                           them at this context size.
  #   --prefill-chunk 2048    keeps context buffers at 6.73 GiB, under the 8 GiB
  #                           threshold in ds4_gpu_should_use_managed_kv_cache()
  #                           that would otherwise force the KV cache onto the
  #                           slower demand-paged managed path at this ctx.
  #                           Benchmarked (ds4-bench, 16k/32k/64k frontiers):
  #                           decode 14.57/13.92/13.07 t/s vs 14.15/13.39/12.45
  #                           on the managed path — and the gap widens with
  #                           depth. Costs ~4% prefill (164.6 vs 170.0 t/s at
  #                           64k), which the disk KV cache largely hides on
  #                           repeated prefixes. Also saves 1.67 GiB, since
  #                           raw_cap tracks the prefill chunk.
  systemd.services.ds4 = {
    description = "DwarfStar (ds4) DeepSeek-V4 inference server";
    after = [ "network.target" ];
    wantedBy = [ ];

    serviceConfig = {
      Type = "simple";
      User = ds4User;
      Group = "users";
      SupplementaryGroups = [ "render" "video" ];
      WorkingDirectory = ds4Home;
      Environment = [ "HOME=/home/${ds4User}" ];

      ExecStart = lib.escapeShellArgs [
        "${config.services.ds4.package}/bin/ds4-server"
        "-m" ds4Model
        "--ctx" "393216"
        "--prefill-chunk" "2048"
        "--kv-disk-dir" "${ds4Home}/server-kv"
        "--kv-disk-space-mb" "131072"
        "--kv-cache-cold-max-tokens" "250000"
        "--host" "0.0.0.0"
      ];

      # ds4 sets its own oom_score_adj=1000 and volunteers as first OOM victim,
      # so recover automatically when it loses that bet. An explicit
      # `systemctl stop` is not a failure and will not be restarted.
      Restart = "on-failure";
      RestartSec = 10;

      # Loading 80.76 GiB of tensors takes ~30s from warm page cache, longer cold.
      TimeoutStartSec = 600;

      # --ssd-streaming's expert cache uses mlock(); systemd units don't pick up
      # the module's PAM limits.
      LimitMEMLOCK = "infinity";
    };
  };

  time.timeZone = "America/Chicago";
}
