{ config, pkgs, lib, nixos-hardware, nixpkgs-master, ... }:
{
  # Dell XPS 13 9350 (2024) w/288v Lunar Lake CPU
  networking.hostName = "xps";

  imports = [
    nixos-hardware.nixosModules.dell-xps-13-9350
    ../includes/gui.nix
    ../includes/ai-desktop.nix
    ../includes/dev.nix
    ../includes/ai.nix
    ../includes/gaming.nix
    ../includes/gnome.nix
    ../includes/printing.nix
    ../includes/dictation.nix # Parakeet on the CPU
  ];

  # The webcam (ov02c10 behind the Intel CVS) needs 7.4's "media: i2c: cvs:
  # Add sensor node in bound callback"; without it the IR sensor (HIMX1092, no
  # driver) keeps the IPU7 notifier from completing and the sensor never gets a
  # /dev/v4l-subdev node, so libcamera can't use it.  Ride the 7.4 RCs until
  # linuxPackages_latest catches up, then this falls back on its own.
  boot.kernelPackages =
    if lib.versionOlder pkgs.linuxPackages_latest.kernel.version "7.4"
    then pkgs.linuxPackages_testing
    else pkgs.linuxPackages_latest;
  # Allow rootless containers to bind ports 80+ (needed for dokku, nginx, etc.)
  boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 80;

  # Default is for 512MB /boot, but this one is 1GB
  boot.loader.systemd-boot.configurationLimit = 10;

  # these customizations should make it into nixos-hardware
  services.fwupd.enable = true;
  services.fprintd.enable = true; # https://github.com/NixOS/nixos-hardware/pull/1835
  hardware.cpu.intel.npu.enable = true; # haven't successfully used it yet

  # Built-in mics are digital, on the rt714 codec's DMIC1/DMIC2 pins, but the
  # rt715-sdca driver comes up with ADCs 22/23 muxed to the unconnected analog
  # MIC1/MIC2 inputs, giving a flat ~-60 dBFS noise floor.  UCM never touches
  # the muxes or the DMIC boost and the codec keeps them across runtime PM, so
  # setting them once when the card appears is enough.  Boost is 0-3 in 10 dB
  # steps: 2 fixes "really quiet" while 3 raises the room noise floor to ~-46 dBFS.
  services.udev.extraRules =
    let
      micSetup = pkgs.writeShellScript "xps-mic-setup" ''
        amixer=${pkgs.alsa-utils}/bin/amixer
        $amixer -q -c sofsoundwire cset name='rt714 ADC 22 Mux' DMIC1
        $amixer -q -c sofsoundwire cset name='rt714 ADC 23 Mux' DMIC2
        $amixer -q -c sofsoundwire cset name='rt714 FU0E Boost' 2,2,2,2,2,2,2,2
      '';
    in
    ''
      ACTION=="add", SUBSYSTEM=="sound", KERNEL=="controlC*", ATTRS{id}=="sofsoundwire", RUN+="${micSetup}"
    '';

  # PipeWire's v4l2 monitor offers each of the 32 raw IPU7 capture nodes as a
  # camera, none of which produce usable frames on their own.  The real camera
  # comes through the libcamera monitor instead.  Match on the udev product
  # name: rules run before the device is opened, so api.v4l2.cap.* isn't set yet.
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/10-hide-ipu7-raw-nodes.conf" ''
      monitor.v4l2.rules = [
        {
          matches = [
            {
              device.product.name = "ipu7"
            }
          ]
          actions = {
            update-props = {
              device.disabled = true
            }
          }
        }
      ]
    '')
  ];

  # Zoom's native client only reads /dev/video* and only takes YUV, but
  # libcamera's software ISP only produces RGB, so pw-v4l2 gives it a black
  # preview.  v4l2-relayd feeds a v4l2loopback device from libcamerasrc as
  # YUY2, and only runs the camera while an app is reading from the device.
  # Pick "Integrated Camera" in Zoom.  It can't share the sensor with PipeWire,
  # so other camera apps see it busy while a call has video on.
  #
  # No videorate: libcamerasrc negotiates 30/1 on its own, and relayd starts
  # the input on the output pipeline's clock, so videorate would backfill
  # duplicates from 0 up to the first real frame on every start and the sink
  # drops them all as late -- ~1 new frame every few seconds.
  services.v4l2-relayd.instances.camera = {
    enable = true;
    cardLabel = "Integrated Camera";
    extraPackages = [ pkgs.libcamera ];
    input.pipeline = "libcamerasrc ! video/x-raw,width=1280,height=720 ! videoconvert";
  };

  environment.systemPackages = with pkgs; [
    virt-manager
    signal-cli
    # burpsuite # pentesting
  ];

  programs.captive-browser = {
    enable = true;
    interface = "wlp0s20f3";
  };

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

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "24.05";
}
