# Dotbox — Agent Guide

## Repo Organization

* bin/ - `install_nix`, `install_dotfiles`, `nirvm` (creates the niri VM), and
  `puma_dev_ca` (generates a machine's puma-dev CA).
* nix/ - NixOS flake. Every `nix/machines/<host>.nix` is a host, built with
  `nix/includes/` modules. See nix/README.md.
* nix/pkgs - Local packages; upstream releases are pinned in `nvfetcher.toml`.
* nix/hardware, nix/puma-dev - Each machine's hardware-configuration.nix and
  puma-dev CA cert, checked in by `bin/install_nix`. Commit them when they change.
* home/ - Dotfiles symlinked to the user's home directory.
* home-files/ - Dotfiles copied to the user's home directory.
* hooks/ - Scripts executed after dotfiles are installed.

## Install Scripts

`bin/install_nix` rebuilds with `nh os boot|switch` straight from `nix/`
(plain `nh os switch` works too), after syncing this machine's hardware config
and puma-dev cert into the repo. The flake only sees git-tracked files, so
`git add` new ones. Hosts without a checked-in hardware config need `--impure`.

`bin/install_dotfiles` installs `home/` and `home-files/` into `$HOME`, then
layers private directories on top (last write wins).
