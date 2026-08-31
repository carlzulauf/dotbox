{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
let
  # Radeon 8060S (Strix Halo). Everything ROCm here stays scoped to this one
  # target: building ROCm for every architecture at once OOMs this box.
  rocmTarget = "gfx1151";

  # One ROCm package set for the whole machine. nixpkgs exposes a per-arch
  # subscope (rocmPackages.<target>) which is exactly the
  # `overrideScope (clr.override { localGpuTargets = [ target ]; })` that
  # ds4.nix applies internally, so handing this same scope to both ds4 and
  # ollama-rocm below makes them share one clr/hipblas/rocblas build rather
  # than evaluating two identical-but-separate sets. ds4 is built either way,
  # so a ROCm-capable ollama costs only rocsolver + rocsparse on top of it,
  # plus ollama's own llama.cpp runner.
  rocmPkgs = nixpkgs-master.rocmPackages.${rocmTarget};

  # ollama-rocm's rocmGpuTargets defaults to rocmPkgs.clr.localGpuTargets, so
  # the GPU target follows rocmTarget without being restated here.
  ollamaRocm = nixpkgs-master.ollama-rocm.override { rocmPackages = rocmPkgs; };
  ollamaVulkan = nixpkgs-master.ollama-vulkan;

  # Which GPU backend ollama uses by default. Both builds stay installed and
  # $OLLAMA_BACKEND overrides this at startup (see ollamaSwitcher), so this is
  # the declared default rather than the only reachable option.
  #
  # Vulkan wins on this iGPU today. Benchmarked 2026-08-21 across the models
  # actually in use, identical blobs and runner settings, one runner at a time,
  # box idle:
  #
  #   model            decode t/s (greedy)      prefill t/s @ ~6.5k tokens
  #                    ROCm  Vulkan   gain      ROCm  Vulkan   gain
  #   qwen3.8:27b     19.11   26.95  +41%        326     294   -10%
  #   ornith-1.5:35b  63.35   76.65  +21%       1318    1037   -21%
  #   gemma4:26b      56.90   66.79  +17%       1491    1412    -5%
  #   qwen3.6:35b     61.64   71.08  +15%       1315    1138   -13%
  #   ornith-1.5:9b   36.81   39.25   +7%       1044     897   -14%
  #   gemma4:12b      25.85   27.33   +6%        717     715    -0%
  #
  # It is a trade, not a free win: Vulkan buys decode and pays prefill. Decode
  # dominates unless the prompt is enormous relative to the reply - break-even
  # is prompt > 45x generated tokens for qwen3.8, and > 11-13x for the ornith
  # pair (their prefill regression is worst). Only an 8k-prompt/500-token-reply
  # shape favours ROCm, and only by ~1%. Every ordinary chat shape favours
  # Vulkan.
  #
  # TREAT THE TABLE AS A DATED SNAPSHOT, NOT A STANDING FACT. It measures one
  # ollama, one mesa/RADV, one kernel and one ROCm; all four move fast and the
  # gap has no reason to hold. Re-run the comparison after any of them jumps -
  # that is what the runtime switch below is for.
  #
  # Caveat for future measurements: prefill throughput on a short (~30 token)
  # prompt is meaningless - it measures fixed per-request overhead and made
  # Vulkan look 23% FASTER at prefill when it is actually 0-21% slower. Measure
  # prefill at >=1k tokens. Likewise measure decode at temperature 0: only
  # qwen3.8 is temperature-sensitive (19.11 -> 15.46 t/s on ROCm at temp 1),
  # being the one model here with an MTP draft head whose acceptance rate drops
  # under stochastic sampling, but that is enough to poison a mixed comparison.
  # Text output and vision (CLIP projector) both verified correct on Vulkan.
  ollamaBackend = "vulkan";

  # Startup shim: `ollama` reads its backend from $OLLAMA_BACKEND, falling back
  # to ollamaBackend. That variable is ours, not ollama's - ollama's own
  # OLLAMA_LLM_LIBRARY picks between runners inside a single build, and nixpkgs
  # compiles exactly one runner per package, so it cannot cross this boundary.
  # Both real builds are installed, so an A/B run is a service restart rather
  # than a rebuild:
  #
  #   systemctl edit --runtime ollama   # [Service] Environment=OLLAMA_BACKEND=rocm
  #   systemctl restart ollama
  #   systemctl revert ollama; systemctl restart ollama   # back to the default
  #
  # `ollama serve` locates its runner libraries (lib/ollama/<backend>/) by
  # walking up from the *resolved* path of the running executable, so the shim
  # has to exec into the real package. Symlinking the two builds into one
  # merged tree would resolve back to whichever original store path won the
  # collision and quietly lose the other backend's runner.
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
    package = ollamaSwitcher;

    # OLLAMA_IGPU_ENABLE is mandatory, not tuning: ollama classifies the 8060S
    # as an integrated GPU and, under Vulkan, silently drops it ("dropping
    # integrated GPU") and falls back to CPU inference unless this is set. ROCm
    # keeps the iGPU either way and is unharmed by it, so it is set for both
    # rather than made conditional on the backend.
    environmentVariables.OLLAMA_IGPU_ENABLE = "1";
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

  assertions = [
    {
      assertion = builtins.elem ollamaBackend [ "vulkan" "rocm" ];
      message = "frix: ollamaBackend must be \"vulkan\" or \"rocm\", got \"${ollamaBackend}\"";
    }
  ];

  time.timeZone = "America/Chicago";
}
