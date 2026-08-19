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
#      so ov02c10 does *not* wait for CVS via ACPI _DEP.  What orders them in
#      practice is that ipu-bridge only instantiates the sensor's I2C client
#      once intel_ipu7 probes, so loading intel_cvs before intel_ipu7 -- the
#      softdep below -- gets CVS bound and its ownership transfer done before
#      ov02c10 ever touches the bus.  ipu7-camera-bind.service is the fallback
#      for when that loses the race, plus the permissions fixup.
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
  isysDriver = "/sys/bus/auxiliary/drivers/intel_ipu7_isys.isys";
  isysDevice = "intel_ipu7.isys.*";

  # In the normal case intel_cvs hands the sensor over in time and ov02c10
  # probes by itself; this service only has to fix up permissions.  The
  # rebind below is the fallback for when it does not, and it deliberately
  # waits for ipu7-isys first: unbinding the sensor after isys has registered
  # its async notifier leaves the notifier stuck waiting forever, and the
  # staging driver never recovers.
  bindSensor = pkgs.writeShellApplication {
    name = "ipu7-camera-bind";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      isys_bound() {
        for link in ${isysDriver}/${isysDevice}; do
          [ -e "$link" ] && return 0
        done
        return 1
      }

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

      # Nothing below is meaningful until ipu7-isys is up to match the sensor.
      for _ in $(seq 1 300); do
        isys_bound && break
        sleep 0.1
      done
      if ! isys_bound; then
        echo "ipu7-isys never bound; leaving the sensor alone" >&2
        exit 1
      fi

      # Give ov02c10 a moment to probe on its own before stepping in.
      for _ in $(seq 1 100); do
        [ -e "${sensorDriver}/${sensorDevice}" ] && break
        sleep 0.1
      done

      if [ -e "${sensorDriver}/${sensorDevice}" ]; then
        echo "ov02c10 is bound to ${sensorDevice}; nothing to do"
        exit 0
      fi

      # Fallback: ov02c10 lost the race with CVS.  Take the sensor, bind, and
      # hand it back so the privacy LED goes out.
      echo "ov02c10 did not bind on its own; taking the sensor and binding it"
      borrowed=""
      if [ "$(cat "${sensorOwner}")" = "cvs" ]; then
        echo ipu > "${sensorOwner}"
        borrowed=1
      fi

      if ! echo "${sensorDevice}" > "${sensorDriver}/bind"; then
        echo "binding ${sensorDevice} to ov02c10 failed" >&2
        [ -n "$borrowed" ] && echo cvs > "${sensorOwner}"
        exit 1
      fi

      if [ -n "$borrowed" ]; then
        # Let isys finish async subdev registration before the sensor stops
        # answering on I2C again.
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

  # This is what actually orders the stack: ipu-bridge does not instantiate
  # the sensor's I2C client until intel_ipu7 probes, so pulling intel_cvs in
  # first gets the CVS ownership transfer done before ov02c10 probes.
  boot.extraModprobeConfig = ''
    softdep intel_ipu7 pre: intel_cvs
  '';

  # ── Sensor handover ───────────────────────────────────────────────────────
  systemd.services.ipu7-camera-bind = {
    description = "Ensure the IPU7 camera sensor is bound and host-takeable";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe bindSensor;
    };
  };

  # Re-run on any later intel_cvs bind: USB resets and resume from suspend
  # both tear the CVS device down and bring it back.  Safe to fire early --
  # the service waits for ipu7-isys and no-ops when ov02c10 is already bound.
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
