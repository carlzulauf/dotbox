# Webcam support for the Dell XPS 13 9350 (Lunar Lake / Core Ultra 288V).
#
# The camera is an OV02C10 (ACPI OVTI02C1) behind the Intel IPU7 ISYS CSI-2
# receiver, reached over a USBIO I2C bridge, with an Intel CVS vision
# coprocessor (ACPI INTC10DE) sitting between the sensor and the IPU.  As of
# kernel 7.1 everything on that path is in-tree -- intel-ipu7/intel-ipu7-isys
# (staging), ipu-bridge, ov02c10, usbio -- and the IPU7 firmware ships in
# linux-firmware.  Two pieces are not:
#
#   1. The CVS owns the sensor's I2C at boot and has no mainline driver.
#      Intel's out-of-tree intel_cvs (drivers/misc/icvs) handles the handover;
#      intel/vision-drivers#36 tracks upstreaming it.
#
#   2. Kernel 7.2 picked up commit c6b1b34b5090 ("media: pci: intel: Add CVS
#      support for IPU bridge driver"), which makes ipu-bridge splice the CVS
#      into the fwnode graph between sensor and IPU:
#
#          OVTI02C1-0/port@0/endpoint@0 -> INTC10DE-0/port@0/endpoint@0
#          INTC10DE-0/port@1/endpoint@0 -> INT343E/port@0/endpoint@0
#
#      ipu7-isys then waits for a v4l2 subdev at INTC10DE-0/port@1/endpoint@0.
#      Nothing provides one: intel_cvs is a misc driver with no v4l2 code, and
#      neither intel/vision-drivers nor intel/ipu7-drivers ships a CVS CSI
#      subdev.  The notifier waits forever, the sensor is never matched, and
#      libcamera reports "No sensor found for /dev/media0".
#
# ipu-bridge only inserts that hop when bus_find_device_by_acpi_dev() finds an
# i2c client for INTC10DE at the moment intel_ipu7 probes; with no CVS device
# it wires the sensor straight to the IPU (see the sensor->csi_dev branches in
# ipu_bridge_create_connection_swnodes).  So the fix here is ordering: keep the
# USBIO bridge -- and hence both i2c clients -- out of the way until
# intel_ipu7 has probed, then bring the stack up by hand in an order that
# works.  That restores the direct sensor->IPU topology which is what the CVS
# passes through anyway, and which worked before c6b1b34b5090 landed.
#
# Userspace is libcamera's `simple` pipeline handler plus the software ISP;
# there is no open driver for the IPU7 hardware ISP.  PipeWire picks the
# camera up through WirePlumber's libcamera monitor, which is what portal
# clients (GNOME Snapshot, Firefox, Chromium) consume.  Applications that
# open /dev/video* directly (Zoom, Discord) still need a v4l2loopback bridge.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  visionDrivers = pkgs.callPackage ./default.nix {
    inherit (config.boot.kernelPackages) kernel kernelModuleMakeFlags;
  };

  # Build libcamera's software ISP with the GPU debayer path (EGL/GLESv2)
  # instead of the CPU one.  Off by default: it is a libcamera 0.7 rebuild,
  # and libcamera is a dependency of PipeWire, so flipping this drags most of
  # the desktop closure along with it.  Worth turning on if CPU use during
  # calls is a problem -- CPU debayer runs around 65% of a core at 1080p30.
  useGpuSoftIsp = false;

  cvsSysfs = "/sys/bus/i2c/devices/i2c-INTC10DE:00";
  sensorOwner = "${cvsSysfs}/sensor_owner";
  sensorDriver = "/sys/bus/i2c/drivers/ov02c10";
  sensorDevice = "i2c-OVTI02C1:00";
  ipuDriver = "/sys/bus/pci/drivers/intel-ipu7";
  cvsSwnode = "/sys/kernel/software_nodes/INTC10DE-0";

  # Everything the deferred modules need, in the one order that produces a
  # working graph.  Idempotent, so udev can re-run it after a USB reset.
  cameraUp = pkgs.writeShellApplication {
    name = "ipu7-camera-up";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.kmod
    ];
    text = ''
      ipu_bound() {
        for link in ${ipuDriver}/0000:*; do
          [ -e "$link" ] && return 0
        done
        return 1
      }

      # 1. ipu-bridge builds the camera fwnode graph inside intel_ipu7's PCI
      #    probe.  Nothing below may run until that has happened, or the CVS
      #    ends up in the graph and the sensor can never be matched.
      for _ in $(seq 1 300); do
        ipu_bound && break
        sleep 0.1
      done
      if ! ipu_bound; then
        echo "intel-ipu7 never bound; bringing the stack up anyway" >&2
      fi

      if [ -e "${cvsSwnode}" ]; then
        echo "ipu-bridge put the CVS in the graph (${cvsSwnode} exists)." >&2
        echo "The USBIO bridge came up before intel_ipu7 probed; the camera" >&2
        echo "will not work this boot.  Check that usbio is still blacklisted." >&2
      fi

      # 2. intel_cvs first, so it is bound and has completed its ownership
      #    transfer before any sensor driver touches the bus.  Its softdep
      #    pulls in usbio, which is what creates the i2c adapters.
      modprobe intel_cvs

      for _ in $(seq 1 300); do
        [ -e "${sensorOwner}" ] && break
        sleep 0.1
      done
      if [ ! -e "${sensorOwner}" ]; then
        echo "intel_cvs never exposed ${sensorOwner}" >&2
        exit 1
      fi

      # Let the video group take the sensor without root.
      chgrp video "${sensorOwner}"
      chmod g+w "${sensorOwner}"

      # 3. Only now is it safe to probe the sensor.  intel_cvs hands the
      #    sensor to the host for ten seconds after probe; if we have missed
      #    that window, borrow it and hand it back once ov02c10 is up.
      borrowed=""
      if [ "$(cat "${sensorOwner}")" = "cvs" ]; then
        echo ipu > "${sensorOwner}"
        borrowed=1
      fi

      modprobe ov02c10

      for _ in $(seq 1 100); do
        [ -e "${sensorDriver}/${sensorDevice}" ] && break
        sleep 0.1
      done

      if [ ! -e "${sensorDriver}/${sensorDevice}" ]; then
        echo "${sensorDevice}" > "${sensorDriver}/bind" || {
          echo "binding ${sensorDevice} to ov02c10 failed" >&2
          [ -n "$borrowed" ] && echo cvs > "${sensorOwner}"
          exit 1
        }
      fi

      if [ -n "$borrowed" ]; then
        # Let ipu7-isys finish async subdev registration before the sensor
        # stops answering on I2C again.
        sleep 1
        echo cvs > "${sensorOwner}"
      fi
    '';
  };

  # The privacy LED is wired to the CVS "req" GPIO, so it is lit for exactly
  # as long as the host holds the sensor.  Capture only works while the host
  # holds it, hence an explicit acquire/release rather than holding it for
  # the whole session.
  ipu7Camera = pkgs.writeShellApplication {
    name = "ipu7-camera";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      owner="${sensorOwner}"

      if [ ! -e "$owner" ]; then
        echo "ipu7-camera: $owner not present; intel_cvs has not bound" >&2
        exit 1
      fi

      case "''${1-status}" in
        status)
          cat "$owner"
          ;;
        acquire)
          echo ipu > "$owner"
          ;;
        release)
          echo cvs > "$owner"
          ;;
        run)
          shift
          echo ipu > "$owner"
          # shellcheck disable=SC2064
          trap "echo cvs > '$owner'" EXIT
          "$@"
          ;;
        *)
          echo "usage: ipu7-camera {status|acquire|release|run <command>...}" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  # ── Kernel ────────────────────────────────────────────────────────────────
  boot.extraModulePackages = [ visionDrivers ];

  # Keep all three out of the boot-time autoload path.  usbio is the one that
  # matters -- it creates i2c-INTC10DE:00, which is what makes ipu-bridge
  # insert the CVS into the graph -- but intel_cvs has a softdep on usbio and
  # would drag it in, and ov02c10 would then probe before the CVS handover.
  # ipu7-camera-up.service loads all three by name once intel_ipu7 is bound;
  # `blacklist` only suppresses alias-driven autoloading, not modprobe.
  boot.blacklistedKernelModules = [
    "usbio"
    "intel_cvs"
    "ov02c10"
  ];

  # ── Bring-up ──────────────────────────────────────────────────────────────
  systemd.services.ipu7-camera-up = {
    description = "Bring up the IPU7 camera stack after ipu-bridge has run";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe cameraUp;
    };
  };

  # Re-run after a USB reset or resume from suspend, both of which tear the
  # USBIO bridge down and bring it back.  The script is idempotent.
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="i2c", DRIVER=="intel_cvs", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ipu7-camera-up.service"
  '';

  # ── Userspace ─────────────────────────────────────────────────────────────
  nixpkgs.overlays = lib.optional useGpuSoftIsp (
    _final: prev: {
      # gles_headless_enabled in src/libcamera/meson.build keys off EGL/egl.h
      # plus the egl and glesv2 pkg-config files, all of which libglvnd
      # provides. With it, software_isp builds debayer_egl.cpp.
      libcamera = prev.libcamera.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ prev.libGL ];
      });
    }
  );

  environment.systemPackages = [
    ipu7Camera
    pkgs.libcamera # `cam` for enumeration and capture smoke tests
    pkgs.v4l-utils # `media-ctl -p`, `v4l2-ctl` for inspecting the ISYS graph
  ];
}
