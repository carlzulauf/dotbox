{ config, pkgs, nixos-hardware, ... }:

{
  # offsite backup machine
  # Ryzen 2400G
  # 32GB DDR4
  # (x2) 4TB SATA SSD
  # 1TB NVMe (boot)
  # 2TB NVMe
  # 4TB external HDD
  # 2TB external HDD
  networking.hostName = "obak";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/gui.nix
      ../includes/tv.nix
    ];

  environment.systemPackages = with pkgs; [
    mergerfs
  ];

  # nix.settings.substituters = [ "http://nax/" ];

  # lsblk --output NAME,LABEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS,UUID

  # 4TB SATA SSD, /dev/sda
  fileSystems."/mnt/offsite1" = {
    device = "/dev/disk/by-uuid/30a23e32-a48e-45ab-b5df-c331336b9b7e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/pile1" = {
    device = "/dev/disk/by-uuid/30a23e32-a48e-45ab-b5df-c331336b9b7e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@files"
    ];
  };

  # 4TB SATA SSD, /dev/sdb
  fileSystems."/mnt/offsite2" = {
    device = "/dev/disk/by-uuid/9c09380e-419d-4414-a000-a4b4aa2b0828";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/pile2" = {
    device = "/dev/disk/by-uuid/9c09380e-419d-4414-a000-a4b4aa2b0828";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@files"
    ];
  };

  # 2TB NVMe SSD, /dev/nvme1n1
  fileSystems."/mnt/offsite3" = {
    device = "/dev/disk/by-uuid/18494df1-da9f-4666-bdc4-1b1ee576b8bb";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/18494df1-da9f-4666-bdc4-1b1ee576b8bb";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@vault"
    ];
  };

  # 4TB USB HDD, /dev/sdc
  fileSystems."/mnt/offsite4" = {
    device = "/dev/disk/by-uuid/3e017f3e-badc-45e0-8413-0d4b63c25b85";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/pile4" = {
    device = "/dev/disk/by-uuid/3e017f3e-badc-45e0-8413-0d4b63c25b85";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@files"
    ];
  };

  # 2TB USB HDD, /dev/sdd
  fileSystems."/mnt/offsite5" = {
    device = "/dev/disk/by-uuid/53d24984-21ab-43dd-a793-47cc086f4865";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/pile5" = {
    device = "/dev/disk/by-uuid/53d24984-21ab-43dd-a793-47cc086f4865";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@files"
    ];
  };

  # mergerfs jbod
  fileSystems."/mnt/files" = {
    depends = [
      "/mnt/pile1"
      "/mnt/pile2"
      "/mnt/pile4"
      "/mnt/pile5"
    ];
    device = "/mnt/pile1:/mnt/pile2:/mnt/pile4:/mnt/pile5";
    fsType = "mergerfs";
    options = [
      "defaults"
      "minfreespace=150G"
      "fsname=merged-files"
    ];
  };

  services.jellyfin =
    let
      configBaseDir = "/home/carl/.local/share/jellyfin";
    in
    {
      enable = true;
      openFirewall = true;
      user = "carl";
      dataDir = configBaseDir;
      logDir = "${configBaseDir}/log";
      cacheDir = "${configBaseDir}/cache";
      configDir = "${configBaseDir}/config";
    };

  time.timeZone = "America/Denver";
}
