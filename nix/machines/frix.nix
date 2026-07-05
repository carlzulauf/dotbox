{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
let
  # necessary because otherwise builds with all arch and hits OOM errors
  rocmPkgs = nixpkgs-master.rocmPackages.overrideScope (_: rprev: {
    clr = rprev.clr.override { localGpuTargets = [ "gfx1151" ]; };
  });

  # ROCm/HIP components ds4's `strix-halo` target compiles and links against.
  # hipcc is NOT cc-wrapped, so it ignores NIX_CFLAGS_COMPILE/NIX_LDFLAGS;
  # we hand it -I/-L/-rpath for each store path explicitly (see ROCM_* below).
  # Header set taken from ds4_rocm.cu / rocm/*.cuh:
  #   hip/* -> clr, hipblas, hipblaslt (+hipblas-common, rocblas),
  #   hipcub (+rocprim), rocwmma.
  rocmDeps = with rocmPkgs; [
    clr
    hipblas hipblaslt hipblas-common rocblas
    hipcub rocprim
    rocwmma
    rocm-core
  ];

  # DS4 (DwarfStar): antirez's native DeepSeek-V4 inference engine.
  # Built here for ROCm / Strix Halo (Radeon 8060S, gfx1151).
  ds4 = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "ds4";
    version = "0-unstable-2026-06-17";

    src = pkgs.fetchFromGitHub {
      owner = "antirez";
      repo = "ds4";
      rev = "80ebbc396aee40eedc1d829222f3362d10fa4c6c";
      hash = "sha256-Ieuc72GHZs20ModQfnvI5Me31n4Pj+WFYtsuqaKJceo=";
    };

    # hipcc is the compiler/linker for the ROCm object + the final link.
    nativeBuildInputs = [ rocmPkgs.hipcc ];
    buildInputs = rocmDeps;

    # The Makefile assigns ROCM_ARCH/ROCM_CFLAGS/ROCM_LDLIBS with `?=`, so
    # exported environment variables win. We keep upstream's flags verbatim
    # and append the include/lib/rpath paths for the split Nix store layout.
    ROCM_ARCH = "gfx1151";
    ROCM_CFLAGS =
      "-O3 -ffast-math -g -fno-finite-math-only -pthread -D__HIP_PLATFORM_AMD__ "
      + "-Wno-unused-command-line-argument --offload-arch=gfx1151 "
      + lib.concatMapStringsSep " " (p: "-I${p}/include") rocmDeps;
    ROCM_LDLIBS =
      "-lm -pthread "
      + lib.concatMapStringsSep " " (p: "-L${p}/lib -Wl,-rpath,${p}/lib") rocmDeps
      + " -lhipblas -lhipblaslt";

    enableParallelBuilding = true;

    buildPhase = ''
      runHook preBuild
      export HIPCC="${rocmPkgs.hipcc}/bin/hipcc"
      export ROCM_PATH="${rocmPkgs.clr}"
      export HIP_PATH="${rocmPkgs.clr}"
      export HIP_DEVICE_LIB_PATH="${rocmPkgs.rocm-device-libs}/amdgcn/bitcode"
      make strix-halo -j"$NIX_BUILD_CORES"
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 -t $out/bin ds4 ds4-server ds4-bench ds4-eval ds4-agent
      install -Dm755 download_model.sh $out/bin/ds4-download-model
      runHook postInstall
    '';

    meta = {
      description = "DwarfStar (ds4): native DeepSeek-V4 inference engine, ROCm/Strix Halo build";
      homepage = "https://github.com/antirez/ds4";
      license = lib.licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
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
    ds4
    # Download script for DS4 GGUF models (optional - add as package)
  ];

  # DS4 Model Information:
  # ---------------------
  # DS4 expects GGUF model files in a `gguf/` subdirectory relative to the binary.
  # The default location after installation is: $out/bin/gguf/
  # 
  # To download models, you can use the official script:
  #   curl -sSL https://raw.githubusercontent.com/antirez/ds4/main/download_model.sh > download_model.sh
  #   chmod +x download_model.sh
  #   ./download_model.sh q2-imatrix
  #
  # Or manually from: https://huggingface.co/antirez/deepseek-v4-gguf/tree/main
  # 
  # Recommended model for Strix Halo (128GB RAM):
  #   DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf
  #
  # After downloading, place the GGUF file in: /run/current-system/sw/bin/gguf/
  # (replace /run/current-system/sw with your Nix store path if needed)

  # ROCm user configuration for DS4 access
  users.users.carl.extraGroups = [ "render" "video" ];

  # Allow ds4-server (started manually) to serve its API on port 8000 across
  # the LAN / all interfaces. Note it's unauthenticated, so anything that can
  # route to the box can reach it.
  networking.firewall.allowedTCPPorts = [ 8000 ];

  # Increase GPU-visible memory for DS4 on Strix Halo (128GB system).
  #
  # IMPORTANT: these only widen the GTT *aperture* (~124 GiB) -- they do nothing
  # unless the OS actually has the RAM to back it. Set the BIOS "UMA Frame Buffer
  # Size" to 512 MB (reboot -> F2 -> Advanced). The default / "Auto" carves out
  # ~32 GiB as dedicated VRAM, which ds4 never uses (it loads the ~80 GiB model
  # into GTT), leaving the OS only ~94 GiB and starving the model into OOM.
  boot.kernelParams = [
    "amd_iommu=off"
    "amdgpu.gttsize=126976"        # 124 GiB (deprecated but harmless; silences ambiguity)
    "ttm.pages_limit=32505856"     # 124 GiB in 4 KiB pages -- the knob that raises the real limit
    "ttm.page_pool_size=32505856"
  ];

  # DS4 loads an 80+ GiB model into GTT-backed system RAM, then sets its own
  # oom_score_adj=1000 so it volunteers as the first OOM victim. The fix is
  # headroom, not fighting the killer.

  # Small NVMe swapfile as an OOM cushion (not for holding weights). zram is
  # intentionally avoided: quantized weights are file-backed + high-entropy, so
  # zram would only steal RAM from the model it is meant to fit.
  swapDevices = [ { device = "/var/lib/swapfile"; size = 32 * 1024; } ];

  # systemd-oomd proactively kills on memory pressure -- counterproductive on a
  # box that intentionally runs near-full for inference. Kernel OOM killer stays.
  systemd.oomd.enable = false;

  boot.kernel.sysctl = {
    "vm.overcommit_memory" = 1;    # don't spuriously reject large KV-cache / compute allocations
    "vm.swappiness" = 10;          # keep the swapfile a true last resort
    "vm.min_free_kbytes" = 262144; # ~256 MiB reclaim reserve on a near-full box
  };

  # ds4's lockable --ssd-streaming expert cache uses mlock(); the 8 MiB default
  # limit is far too small (full-residency GTT loads don't need this).
  security.pam.loginLimits = [
    { domain = "@wheel"; type = "-"; item = "memlock"; value = "unlimited"; }
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
