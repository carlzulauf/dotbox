# Creates a bootable ISO file in result/ that can be written to USB thumb drives

# Build me via the flake, so custom inputs (nixpkgs-master, nixpkgs-2605, etc.)
# used by the shared includes are available:
# $ nix build ./nix#nixosConfigurations.iso.config.system.build.isoImage

# `self` is the flake input for this repo (passed via specialArgs in flake.nix).
# self.outPath points at the flake dir (nix/, because of `?dir=nix`), while
# self.sourceInfo.outPath is the whole git tree root. We bundle the whole repo
# so you can install from the flake offline:
#   sudo nixos-install --flake /etc/dotbox/nix#<host>
{ config, pkgs, lib, nixpkgs, self, ... }:
let
  dotbox = self.sourceInfo.outPath; # entire dotbox repo (git-tracked files)
in
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"

    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
    ./includes/defaults.nix
    ./includes/gui.nix
    ./includes/gnome.nix
  ];

  # Read-only copy of the whole repo at /etc/dotbox (symlink into the store).
  # This is enough for `nixos-install --flake /etc/dotbox/nix#<host>`.
  environment.etc.dotbox.source = dotbox;

  # Also drop a writable copy in the live user's home so you can tweak configs
  # or `git commit` before installing. Runs once per boot if not already present.
  system.activationScripts.dotbox = ''
    if [ ! -e /home/nixos/dotbox ]; then
      cp -r ${dotbox} /home/nixos/dotbox
      chmod -R u+w /home/nixos/dotbox
      chown -R nixos:users /home/nixos/dotbox
    fi
  '';
}
