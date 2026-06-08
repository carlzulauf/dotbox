# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the automated hardware scan.
      ./hardware-configuration.nix
      # ./includes/defaults.nix
      # machine specific configs, like hostname, screen rotation, etc
      # ./machine.nix
    ];

  # use binary cache on local network, if we can see it
  # nix.settings.substituters = [
  #   "http://192.168.35.229/"
  #   "https://cache.nixos.org/"
  # ];
  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  system.stateVersion = "24.05";

}
