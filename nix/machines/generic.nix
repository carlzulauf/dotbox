{ config, pkgs, ... }:

{
  # Generic host for initial installs. Deliberately free of any
  # hardware-, CPU-, GPU-, or partition-specific config (no nixos-hardware
  # modules, no fileSystems, no boot device). Those come from the
  # hardware-configuration.nix generated on the target machine at install
  # time. The bootloader, base packages, and the `carl` user are provided by
  # configuration.nix / includes/defaults.nix / includes/carl.nix via mkHost.
  #
  networking.hostName = "generic";

  imports =
    [
      ../includes/gui.nix
      ../includes/gnome.nix
    ];
}
