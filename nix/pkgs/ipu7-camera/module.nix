# Webcam support for the Dell XPS 13 9350 (Lunar Lake / Core Ultra 288V).
#
# The camera is an OV02C10 (ACPI OVTI02C1) behind the Intel IPU7 ISYS CSI-2
# receiver, reached over a USBIO I2C bridge.  As of kernel 7.1 everything on
# that path is in-tree -- intel-ipu7/intel-ipu7-isys (staging), ipu-bridge,
# ov02c10, usbio, and INTC10B5 pinctrl -- and the IPU7 firmware ships in
# linux-firmware.  Two pieces are still missing upstream:
#
#   1. The CVS coprocessor (ACPI INTC10DE) owns the sensor at boot and has no
#      mainline driver, so ov02c10's I2C reads fail with -EREMOTEIO.  Intel's
#      out-of-tree intel_cvs handles the handover (intel/vision-drivers#36
#      tracks upstreaming it).
#
#   2. Upstream lists INTC10DE in acpi_ignore_dep_ids[] (commit 4405a214df14),
#      so ov02c10 does *not* wait for CVS and probes -- and fails -- early in
#      boot regardless of module load order.  A modprobe softdep cannot fix
#      this; it orders module loading, not device probing.  Until the pending
#      "media: ipu-bridge: Add DMI quirk for CVS-sensor dependency" lands, the
#      fix is to rebind ov02c10 once intel_cvs has taken the sensor.
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

  bindSensor = pkgs.writeShellApplication {
    name = "ipu7-camera-bind";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      # intel_cvs creates sensor_owner when it binds, which happens only after
      # the USBIO bridge has enumerated its I2C adapters.
      for _ in $(seq 1 300); do
        [ -e "${sensorOwner}" ] && break
        sleep 0.1
      done

      if [ ! -e "${sensorOwner}" ]; then
        echo "intel_cvs never exposed ${sensorOwner}; is the module loaded?" >&2
        exit 1
      fi

      # Let the video group take the sensor without root.
      chgrp video "${sensorOwner}"
      chmod g+w "${sensorOwner}"

      # intel_cvs holds the sensor for ten seconds after probe so that
      # dependent drivers can bind.  If we are still inside that window just
      # rebind and let its timer hand the sensor back; if we missed it, take
      # the sensor ourselves and release it once ov02c10 is up.
      borrowed=""
      if [ "$(cat "${sensorOwner}")" = "cvs" ]; then
        echo ipu > "${sensorOwner}"
        borrowed=1
      fi

      if [ -e "${sensorDriver}/${sensorDevice}" ]; then
        echo "${sensorDevice}" > "${sensorDriver}/unbind"
      fi
      echo "${sensorDevice}" > "${sensorDriver}/bind"

      if [ -n "$borrowed" ]; then
        # Give ipu7-isys time to finish async subdev registration before the
        # sensor stops answering on I2C again.
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

  # intel_cvs autoloads off the INTC10DE ACPI modalias and carries its own
  # softdep on the USBIO modules, but load it explicitly so a failure is
  # visible in the journal rather than silent.
  boot.kernelModules = [ "intel_cvs" ];

  # Best effort at getting CVS bound before ipu-bridge instantiates the
  # sensor's I2C client.  It usually loses the race against USB enumeration,
  # which is what ipu7-camera-bind.service is for, but it costs nothing.
  boot.extraModprobeConfig = ''
    softdep intel_ipu7 pre: intel_cvs
  '';

  # ── Sensor handover ───────────────────────────────────────────────────────
  systemd.services.ipu7-camera-bind = {
    description = "Bind the IPU7 camera sensor once intel_cvs has released it";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe bindSensor;
    };
  };

  # Re-run on any later intel_cvs bind: USB resets and resume from suspend
  # both tear the CVS device down and bring it back.
  services.udev.extraRules = ''
    ACTION=="bind", SUBSYSTEM=="i2c", DRIVER=="intel_cvs", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ipu7-camera-bind.service"
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
