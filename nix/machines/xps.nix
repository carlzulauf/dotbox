{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
{
  # Dell XPS 13 9350 (2024) w/288v Lunar Lake CPU
  networking.hostName = "xps";

  imports = [
    nixos-hardware.nixosModules.dell-xps-13-9350
    ../includes/gui.nix
    ../includes/dev.nix
    ../includes/ai.nix
    ../includes/gaming.nix
    ../includes/gnome.nix
    ../includes/gnome-hidpi.nix
    ../includes/gnome-niri.nix
    ../includes/printing.nix
    ../pkgs/ipu7-camera/module.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Allow rootless containers to bind ports 80+ (needed for dokku, nginx, etc.)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Add INTC10B5 pinctrl support for Dell XPS 13 9350 camera
  # (GPIO controller needed by ov02c10 sensor driver)
  boot.kernelPatches = [ {
    name = "pinctrl-intel-platform-INTC10B5";
    patch = ../pkgs/ipu7-camera/patch-pinctrl.patch;
  } ];

  # these customizations should make it into nixos-hardware
  services.fwupd.enable = true;
  services.fprintd.enable = true; # https://github.com/NixOS/nixos-hardware/pull/1835
  hardware.cpu.intel.npu.enable = true; # haven't successfully used it yet

  environment.systemPackages = with pkgs; [
    virt-manager
    signal-cli
    # burpsuite # pentesting
  ];

  # this machine is on public wifi a lot and doesn't need to externally serve models
  services.ollama = {
    host = "127.0.0.1";
  };
  services.open-webui = {
    host = "127.0.0.1";
    environment = {
      WEBUI_AUTH = "False";
    };
  };

  services.puma-dev = {
    enable = true;
    user = "carl";
  };

  # --- Timezone & Location ---
  time.timeZone = "America/Chicago";
}
