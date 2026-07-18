{ config, pkgs, nixos-hardware, ... }:

{
  # Ryzen 3700X desktop
  networking.hostName = "nixd";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      # nixos-hardware.nixosModules.common-cpu-amd-zenpower # failing 3/26/2025
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/dev.nix
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

  # hardware.graphics = {
  #   enable = true;       #--> Might not be needed
  #   enable32Bit = true;  # /
  #   extraPackages = with pkgs; [ rocmPackages.clr.icd ]; # OpenCL
  # };

  environment.systemPackages = with pkgs; [
    lact # control amdgpu
    # clinfo # verify OpenCL
  ];
  systemd.packages = with pkgs; [ lact ];
  systemd.services.lactd.wantedBy = ["multi-user.target"];

  time.timeZone = "America/Chicago";
}
