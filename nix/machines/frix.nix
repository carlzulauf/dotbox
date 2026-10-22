{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
let
  # Radeon 8060S (Strix Halo). Everything ROCm here stays scoped to this one
  # target: building ROCm for every architecture at once OOMs this box.
  rocmTarget = "gfx1151";

  rocmPkgs = nixpkgs-master.rocmPackages.${rocmTarget};
  ollamaRocm = nixpkgs-master.ollama-rocm.override { rocmPackages = rocmPkgs; };
  ollamaVulkan = nixpkgs-master.ollama-vulkan;

  # vulkan generally outperformed ROCm during previous benchmarks, but due for retest
  ollamaBackend = "vulkan";

  ollamaSwitcher = pkgs.writeShellScriptBin "ollama" ''
    case "''${OLLAMA_BACKEND:-${ollamaBackend}}" in
      vulkan)
        exec ${lib.getExe ollamaVulkan} "$@"
        ;;
      rocm)
        # ROCm 7.2 supports gfx1151 natively, so this override is an identity
        # mapping; kept because it is what the benchmarked ROCm configuration
        # ran with. Overridable from the environment.
        export HSA_OVERRIDE_GFX_VERSION="''${HSA_OVERRIDE_GFX_VERSION:-11.5.1}"
        exec ${lib.getExe ollamaRocm} "$@"
        ;;
      *)
        echo "ollama: OLLAMA_BACKEND must be 'vulkan' or 'rocm', got '$OLLAMA_BACKEND'" >&2
        exit 1
        ;;
    esac
  '';

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

  # Default is for 512MB /boot, but this one is 1GB
  boot.loader.systemd-boot.configurationLimit = 10;

  imports =
    [
      nixos-hardware.nixosModules.common-pc-ssd
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-gpu-amd
      nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/gnome-cosmic.nix
      ../includes/dev.nix
      ../includes/printing.nix
      ../includes/steam.nix
      ../includes/dictation.nix
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

  programs.steam = {
    # Required for wayland desktop capture during game streaming
    package = pkgs.steam.override { extraArgs = "-pipewire"; };
    # better input handling for game streaming, without portals
    extest.enable = true;
  };

  services.fwupd.enable = true;

  # Super+Q dictates with Cohere Transcribe (CPU), Super+Shift+Q with Whisper
  # large-v3-turbo (GPU). Swap engine and alternateEngine to swap the keys.
  dotbox.dictation = {
    vulkan = true;
    models = {
      cohere = "cohere-transcribe-q4f16";
      whisper = "large-v3-turbo";
    };
    engine = "cohere";
    alternateEngine = "whisper";
  };

  services.ollama = {
    package = ollamaSwitcher;
    # The giant 8060S is technically an iGPU, and, yes, Ollama should use it
    environmentVariables.OLLAMA_IGPU_ENABLE = "1";
  };

  # Sometimes we don't want ollama to start by default since where using DS4
  # or something else heavily, but for now this is commented out so it starts.
  # systemd.services.ollama.wantedBy = lib.mkForce [ ];
  # $ sudo systemctl start ollama

  # Don't auto-start open-webui on frix. It's kind of a hog.
  systemd.services.open-webui.wantedBy = lib.mkForce [ ];
  # $ sudo systemctl start open-webui

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
    # Same scope ollama-rocm gets above, so the two share one ROCm build.
    # ds4.nix re-applies its own localGpuTargets override on top; with matching
    # targets that is a no-op and the derivations stay identical.
    rocmPackages = rocmPkgs;
    rocmGpuTarget = rocmTarget;
  };

  # ds4-server as a manually managed unit: `systemctl start|stop ds4`.
  # Like ollama/open-webui above it never autostarts — the ~80 GiB model plus
  # ROCm overhead leaves only ~16 GiB headroom, so only one runner at a time.
  #
  # Settings rationale (measured on this box at ctx=393216, prefill_chunk=2048:
  # KV 5.23 GiB + buffers 1.50 GiB + model 80.76 GiB):
  #   --ctx 524288            2^19. Think Max needs >= 393216; beyond that the
  #                           ceiling is the managed-KV threshold below, not
  #                           RAM. Compressed KV is ~13.1 KiB/token, so this
  #                           plans KV 6.82 GiB + buffers 1.00 GiB = 7.82 GiB.
  #                           The model supports 1048576, but that is ~15.5
  #                           GiB of context and lands on the managed path.
  #   --kv-disk-space-mb      8192 filled up and evicted constantly; there are
  #                           2 TB free on this disk and it costs no RAM.
  #   --kv-cache-cold-max-tokens
  #                           default 30000 means cold prompts past 30k tokens
  #                           are never checkpointed at all, which is most of
  #                           them at this context size.
  #   --prefill-chunk 1024    keeps context buffers (KV + 2*comp_cap*chunk*4B)
  #                           under the 8 GiB threshold in
  #                           ds4_gpu_should_use_managed_kv_cache() that would
  #                           otherwise force the KV cache onto the slower
  #                           demand-paged managed path; 2048 would be 8.91 GiB
  #                           at this ctx. At ctx=393216 we benchmarked 2048
  #                           (ds4-bench, 16k/32k/64k frontiers): decode
  #                           14.57/13.92/13.07 t/s vs 14.15/13.39/12.45 on the
  #                           managed path — and the gap widens with depth — for
  #                           ~4% prefill (164.6 vs 170.0 t/s at 64k). 1024
  #                           likely costs somewhat more prefill (unmeasured),
  #                           which the disk KV cache largely hides on
  #                           repeated prefixes.
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
        "--ctx" "524288"
        "--prefill-chunk" "1024"
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

  assertions = [
    {
      assertion = builtins.elem ollamaBackend [ "vulkan" "rocm" ];
      message = "frix: ollamaBackend must be \"vulkan\" or \"rocm\", got \"${ollamaBackend}\"";
    }
  ];

  time.timeZone = "America/Chicago";

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "24.05";
}
