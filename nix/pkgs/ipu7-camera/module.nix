{ lib, pkgs, config, ... }:

let
  visionDrivers = pkgs.callPackage ./default.nix {
    kernel = pkgs.linuxPackages_latest.kernel;
    kernelModuleMakeFlags = pkgs.linuxPackages_latest.kernelModuleMakeFlags;
  };

  # Helper script: acquires the IPU7 camera sensor via sensor_owner sysfs.
  # The patched intel_cvs driver auto-releases the sensor 10s after probe
  # (to turn off the camera LED).  This script re-acquires it on demand.
  acquireSensorScript = pkgs.writeScript "acquire-ipu7-sensor" ''
    #!/bin/sh
    # Acquire the IPU7 camera sensor after CVS has probed and (possibly)
    # auto-released it.  The sensor_owner sysfs attribute is exposed by
    # the patched intel_cvs driver at:
    #   /sys/bus/i2c/devices/i2c-INTC10DE:00/sensor_owner
    #
    # Writing "ipu" acquires the sensor (LED on, camera usable).
    # Writing "cvs" releases it (LED off).

    set -e

    CVS_SYSFS="/sys/bus/i2c/devices/i2c-INTC10DE:00/sensor_owner"

    # Wait up to 30 seconds for the CVS device and sensor_owner attribute
    for i in $(seq 1 30); do
      if [ -f "$CVS_SYSFS" ]; then
        break
      fi
      sleep 1
    done

    if [ ! -f "$CVS_SYSFS" ]; then
      echo "acquire-ipu7-sensor: CVS sensor_owner sysfs not found after 30s" >&2
      exit 1
    fi

    # Read current owner
    OWNER=$(cat "$CVS_SYSFS" 2>/dev/null || echo "unknown")

    if [ "$OWNER" = "ipu" ]; then
      echo "acquire-ipu7-sensor: sensor already owned by IPU"
      exit 0
    fi

    # Acquire the sensor
    echo "ipu" > "$CVS_SYSFS"
    echo "acquire-ipu7-sensor: sensor acquired by IPU"
  '';

in {
  # ─── Kernel module setup ──────────────────────────────────────────
  # Load intel_cvs at boot so it binds to the CVS ACPI device before
  # the ov02c10 sensor probes.  The vision-driver module's own softdep
  # already declares a dependency on usbio/gpio-usbio/i2c-usbio.
  boot.kernelModules = [ "intel_cvs" ];

  # Ensure ov02c10 loads after intel_cvs by declaring a softdep.
  # This works around the kernel's acpi_ignore_dep_ids[] for INTC10DE
  # which otherwise lets the sensor probe before CVS is ready.
  boot.extraModprobeConfig = ''
    softdep ov02c10 pre: intel_cvs
  '';

  # Place the built module where modprobe can find it.
  boot.extraModulePackages = [ visionDrivers ];

  # ─── udev rules ──────────────────────────────────────────────────
  services.udev.extraRules = ''
    # Grant non-root users access to the IPU7 PSYS device
    KERNEL=="ipu7-psys0", MODE="0666", SYMLINK+="ipu-psys0"

    # When CVS I2C device appears (boot, USB reset, resume), acquire
    # the camera sensor so libcamera/PipeWire can use it.
    SUBSYSTEM=="i2c", KERNEL=="i2c-INTC10DE:00", TAG+="systemd", ENV{SYSTEMD_WANTS}+="acquire-ipu7-sensor.service"
  '';

  # ─── Userspace packages ──────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    libcamera
    libcamera-qcam
    # Provide a basic sensor config so libcamera doesn't fall back to
    # uncalibrated.yaml.  Proper tuning requires a calibrated camera
    # sensor properties database.
    (runCommandLocal "ov02c10-libcamera-config" { } ''
      mkdir -p $out/share/libcamera/ipa/simple
      cat > $out/share/libcamera/ipa/simple/ov02c10.yaml << 'CONFIG'
      # SPDX-License-Identifier: CC0-1.0
      %YAML 1.1
      ---
      version: 1
      algorithms:
        - BlackLevel:
            black: 16
        - Awb:
        - Adjust:
        - Agc:
      CONFIG
      # Also provide the alias with I2C bus-address suffix
      ln -sf ov02c10.yaml $out/share/libcamera/ipa/simple/ov02c10\ 14-0036.yaml
    '')
  ];

  # ─── Sensor management service ───────────────────────────────────
  # Triggered by udev (via SYSTEMD_WANTS) when CVS appears, and also
  # runs at boot after udev settles as a fallback.
  systemd.services.acquire-ipu7-sensor = {
    description = "Acquire IPU7 camera sensor after CVS driver is ready";
    after = [ "systemd-udev-settle.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = "${acquireSensorScript}";
    };
  };

  # ─── GNOME Camera (snapshot) workaround ─────────────────────────
  # snapshot uses GStreamer GL on Intel Arc/Wayland, which has a known
  # crash bug.  Setting GST_GL_API=1 forces software rendering.
  environment.sessionVariables = {
    GST_GL_API = "1";
  };
}
