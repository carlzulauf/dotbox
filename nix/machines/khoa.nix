{ config, pkgs, nixos-hardware, ... }:

{
  # old system76 laptop with 8550u
  networking.hostName = "khoa"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  imports =
    [
      nixos-hardware.nixosModules.common-pc-laptop
      nixos-hardware.nixosModules.common-pc-ssd
      nixos-hardware.nixosModules.common-cpu-intel
      ../includes/gui.nix
      ../includes/printing.nix
    ];

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.partitionmanager kdePackages.plasma-disks kdePackages.kate
    qbittorrent qbittorrent-nox
    deskflow
  ];

  # lsblk --output NAME,SIZE,TYPE,MOUNTPOINTS,UUID
  fileSystems."/mnt/lake" = {
    device = "/dev/disk/by-uuid/92b30717-7bc6-4df5-a591-d4d34a2146c7";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/92b30717-7bc6-4df5-a591-d4d34a2146c7";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@backup"
    ];
  };

  fileSystems."/mnt/shore" = {
    device = "/dev/disk/by-uuid/92b30717-7bc6-4df5-a591-d4d34a2146c7";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@shore"
    ];
  };

  fileSystems."/mnt/pond" = {
    device = "/dev/disk/by-uuid/15e65a18-cc7f-4dcb-a787-ce66cdf9650b";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/fountain" = {
    device = "/dev/disk/by-uuid/15e65a18-cc7f-4dcb-a787-ce66cdf9650b";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@fountain"
    ];
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = true;
    user = "carl";
    # profileDir = "/home/carl/.config/qBittorrent";
    # package = pkgs.qbitorrent-nox; # this should already be the default
  };

  time.timeZone = "America/Chicago";
}
