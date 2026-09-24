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
    ../includes/printing.nix
    # ../pkgs/ipu7-camera/module.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Allow rootless containers to bind ports 80+ (needed for dokku, nginx, etc.)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Default is for 512MB /boot, but this one is 1GB
  boot.loader.systemd-boot.configurationLimit = 10;

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

  # Built-in mics are digital, wired to the rt714 codec's DMIC1/DMIC2 pins, but
  # the rt715-sdca driver powers up with ADC 22/23 muxed to the analog MIC1/MIC2
  # pins, which have nothing attached -- capture then yields a flat ~-60 dBFS
  # noise floor while a Bluetooth headset mic still works fine.  Upstream's UCM
  # profile only toggles the FU02 capture switch and never touches the muxes, so
  # extend the Mic enable sequence to point the ADCs at the digital mics.
  # alsa-lib symlinks its share/alsa/ucm2 into this package, so overriding it
  # reaches PipeWire.
  #
  # Disabling due to this causing updates to take hours of compilation (on frix!)
  # Also, the mic is still really quiet.
  # nixpkgs.overlays = [
  #   (_final: prev: {
  #     alsa-ucm-conf = prev.alsa-ucm-conf.overrideAttrs (old: {
  #       postInstall = (old.postInstall or "") + ''
  #         substituteInPlace $out/share/alsa/ucm2/sof-soundwire/rt715-sdca.conf \
  #           --replace-fail \
  #             "cset \"name='rt714 FU02 Capture Switch' 1\"" \
  #             "cset \"name='rt714 FU02 Capture Switch' 1\"
	# 	cset \"name='rt714 ADC 22 Mux' DMIC1\"
	# 	cset \"name='rt714 ADC 23 Mux' DMIC2\""
  #       '';
  #     });
  #   })
  # ];

  services.puma-dev = {
    enable = true;
    user = "carl";
  };
}
