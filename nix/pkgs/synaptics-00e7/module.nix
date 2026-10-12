# Fingerprint login for the Synaptics 06cb:00e7 sensor in the HP Envy x360
# 13-ay.  Stock libfprint lists this ID as unsupported, and none of the
# nixpkgs TOD drivers (goodix, elan, ...) claim it; ./default.nix builds a
# reverse-engineered TOD module for it instead.
#
# The sensor does match-on-chip behind a TLS-like session, keyed by a host
# identity (EC keypair + PSK) the driver reads from /var/lib/fpdrv/pairdata.
# That identity is generated locally -- no Windows pairing involved -- so it's
# created once on first boot below.  Enrolled templates live on the sensor;
# regenerating the pairdata may orphan them, so clear them with
# `fpdrv proto-clear` (with fprintd stopped) and re-enroll if that happens.
#
# Enroll with `fprintd-enroll`.  Enabling fprintd also turns on fingerprint
# auth in PAM (login, sudo, gdm, the lock screen) with password fallback.
{ pkgs, ... }:

let
  fpdrv = pkgs.callPackage ./default.nix { };
in
{
  services.fprintd = {
    enable = true;
    tod.enable = true;
    tod.driver = fpdrv;
  };

  systemd.services.fpdrv-pairdata = {
    description = "Generate the host pairing identity for the 06cb:00e7 fingerprint sensor";
    wantedBy = [ "fprintd.service" ];
    before = [ "fprintd.service" ];
    unitConfig.ConditionPathExists = "!/var/lib/fpdrv/pairdata";
    # pair-init writes $XDG_STATE_HOME/fpdrv/pairdata, which is where the
    # driver looks when fprintd runs as root.
    environment.XDG_STATE_HOME = "/var/lib";
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "fpdrv";
      StateDirectoryMode = "0700";
      ExecStart = "${fpdrv}/bin/fpdrv pair-init";
      # It prints a prefix of the PSK; keep that out of the journal.
      StandardOutput = "null";
    };
  };

  # The fpdrv CLI for diagnostics and on-chip template management; it needs
  # root for the USB device, and fprintd stopped so it can claim it.
  environment.systemPackages = [ fpdrv ];
}
