# Creates a bootable ISO file in result/ that can be written to USB thumb drives

# Build me with nix-build
# $ nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=iso.nix

{ config, pkgs, ... }:
{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix>

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ./includes/defaults.nix
    ./includes/gui.nix
    ./includes/gnome.nix
  ];
}
