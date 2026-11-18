# Dotbox — Agent Guide

Provides a guide to agents or others for working in this repo.

## Repo Organization

* bin/ - Contains nix installer, dotfiles installer, `nirvm` (creates the niri VM),
  and `puma_dev_ca` (generates a machine's puma-dev CA).
* nix/ - Contains base NixOS configuration
* nix/includes - Contains reusable nix modules that are included in machine configs
* nix/machines - Contains per-physical-machine configs for user's NixOS systems
* nix/hardware - Each machine's hardware-configuration.nix, checked in by bin/install_nix
* nix/puma-dev - Public cert of each machine's puma-dev CA, checked in by bin/install_nix
* home/ - Dotfiles symlinked to user's home directory.
* home-files/ - Dotfiles copied to the user's home directory.
* hooks/ - Scripts executed after dotfiles are installed

## The Two Install Scripts

### `bin/install_nix` — NixOS Rebuilds

Rebuilds the machine with `nh os boot|switch`, straight from the flake in
`nix/` (plain `nh os switch` works too). The flake only sees git-tracked
files, so `git add` new files.

It first syncs two machine-local files into the repo, which the flake builds
with: `/etc/nixos/hardware-configuration.nix` to `nix/hardware/<host>.nix`,
and, where `services.puma-dev` is enabled, the public cert of the puma-dev CA
in `~/.puma-dev-ssl/` (made by `bin/puma_dev_ca`) to `nix/puma-dev/<host>.pem`.
Commit them when they change. Hosts without a hardware file build with
`--impure`.

### `bin/install_dotfiles` — Home Directory Setup

**Purpose**: Install dotfiles from `home/` and `home-files/` (and optional
private directories) into the user's `$HOME`.

**Key design**: Layered installation with "last-write-wins" semantics. Base
dotfiles come from `home/` and `home-files/`, then private directories are
layered on top.
