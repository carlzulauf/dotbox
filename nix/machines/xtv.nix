{ config, pkgs, nixos-hardware, ... }:

{
  # Minisforum tv gaming machine
  # 6900hx + 6650m
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

  # ──────────────────────────────────────────────────────────────────
  # Audio: prefer HDMI/DisplayPort over S/PDIF as default output
  # ──────────────────────────────────────────────────────────────────
  # The Navi 21/23 HDMI/DP Audio Controller has priority.session=696,
  # while the USB S/PDIF adapter (Unitek Y-247A) has 1108.  When
  # Bluetooth headphones disconnect, WirePlumber's default-node
  # selection picks the highest-priority available sink, so S/PDIF
  # wins even though HDMI is the preferred output.
  #
  # This WirePlumber config bumps HDMI's priority above S/PDIF so
  # the HDMI output is always selected as the fallback default.
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-prefer-hdmi-audio.conf" ''
      monitor.alsa.rules = [
        {
          matches = [
            {
              node.name = "~alsa_output.pci-0000_03_00.1.hdmi-stereo"
            }
          ]
          actions = {
            update-props = {
              priority.session = 2000
            }
          }
        }
      ]
    '')
  ];
}
