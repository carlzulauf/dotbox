{ config, pkgs, nixos-hardware, ... }:

{
  # Minisforum tv gaming machine
  # 6800hx + 6650m
  networking.hostName = "xtv";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      # nixos-hardware.nixosModules.common-cpu-amd-zenpower # failing 3/26/2025
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/tv.nix
      ../includes/gaming.nix
      ../includes/printing.nix
    ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # environment.systemPackages = with pkgs; [ ];

  # found windows drive via `map -c` and trying to run `X:\EFI\Microsoft\Boot\Bootmgfw.efi`
  boot.loader.systemd-boot.windows = {
    wm2 = {
      title = "Windows 11";
      efiDeviceHandle = "HD1b";
    };
  };

  time.timeZone = "America/Chicago";

  services.ollama = {
    package = pkgs.ollama-rocm;
  };

  services.open-webui = {
    environment = {
      WEBUI_AUTH = "False";
    };
  };

  services.gnome.gnome-remote-desktop.enable = true;
  systemd.services.gnome-remote-desktop = {
    wantedBy = [ "graphical.target" ];
  };
}
