{ config, pkgs, nixos-hardware, hermes-agent, ... }:

{
  # Ryzen 3700X desktop
  networking.hostName = "nixd";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/gaming.nix
      ../includes/printing.nix
    ];


  fileSystems."/mnt/eldon" = {
    device = "/dev/disk/by-uuid/bbeb7483-c5dd-4913-97fb-4215ccf8670a";
    fsType = "btrfs";
    options = [
      "defaults"
      "ssd"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/files" = {
    device = "/dev/disk/by-uuid/bbeb7483-c5dd-4913-97fb-4215ccf8670a";
    fsType = "btrfs";
    options = [
      "defaults"
      "ssd"
      "subvol=/@files"
    ];
  };

  # nix.settings.substituters = [ "http://nax/" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    # https://wiki.archlinux.org/title/AMDGPU#Overclocking
    # unlocks full clock/voltage control
    # value to unlock everything, even experimental: amdgpu.ppfeaturemask=0xffffffff
    # this bash command suggests a different value: amdgpu.ppfeaturemask=0xfff7ffff
    # $ printf 'amdgpu.ppfeaturemask=0x%x\n' "$(($(cat /sys/module/amdgpu/parameters/ppfeaturemask) | 0x4000))"
    "amdgpu.ppfeaturemask=0xfff7ffff"
  ];

  # From https://nixos.wiki/wiki/AMD_GPU
  # "Make the kernel use the correct driver early"
  boot.initrd.kernelModules = [ "amdgpu" ];

  # allow manual power/speed control
  hardware.amdgpu.overdrive.enable = true;
  programs.corectrl.enable = true;

  services.displayManager.gdm.autoSuspend = false;

  # box is mostly for agent use and we want it to have full access, so ditch sudo passwords
  security.sudo.wheelNeedsPassword = false;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [ vulkan-tools ];
  };

  # Ollama sizes the default context from available VRAM (4k/32k/256k tiers), and
  # on this 8GB card it lands on the bottom tier: 4096 tokens, regardless of the
  # model's own context length. Long agent runs then die with "reached the maximum
  # output token limit" as soon as prompt+output crosses that line.
  #
  # 32k is the largest window that stays fully resident on the RX 6650 XT
  # (~41 tok/s on a 9B Q4_K_M). At 40k the Vulkan driver reports 100% GPU but is
  # really spilling into GTT, and the rate halves to ~18 tok/s.
  #
  # The q8_0 KV cache is what buys that window: it roughly halves KV memory
  # (594 MiB vs 1074 MiB at 32k), which is the difference between all 34 layers
  # on the GPU and one spilling to CPU. It is set here rather than in ai.nix
  # because a quantized V cache hard-fails to load ("quantized V cache was
  # requested, but this requires Flash Attention") on any backend where
  # llama.cpp's flash-attn autodetection declines, and the other AI hosts run
  # different backends (ROCm on frix/xtv, Intel Vulkan on xps) that aren't
  # verified. OLLAMA_FLASH_ATTENTION is intentionally left unset: `auto` already
  # turns flash attention on here, and forcing it only removes the fallback.
  services.ollama.environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = "32768";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
  };

  services.open-webui = {
    environment = {
      WEBUI_AUTH = "False";
    };
  };

  environment.systemPackages = with pkgs; [
    lact # control amdgpu
    vulkan-tools # vulkaninfo for GPU debugging

    # Hermes agent CLI: `hermes --tui` for the TUI, `hermes dashboard` for the
    # web UI. Deliberately NOT using hermes-agent.nixosModules.default — that
    # module renders ~/.hermes/config.yaml from nix, making config read-only.
    # Installed as a plain package, all config stays mutable in ~/.hermes.
    hermes-agent.packages.${pkgs.system}.default
  ];
  systemd.packages = with pkgs; [ lact ];
  systemd.services.lactd.wantedBy = ["multi-user.target"];

  time.timeZone = "America/Chicago";
}
