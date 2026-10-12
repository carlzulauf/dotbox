# Dotbox — Agent Guide

Provides a guide to agents or others for working in this repo.

## Repo Organization

* bin/ - Contains nix installer, dotfiles installer, and `nirvm` (creates the niri VM).
* nix/ - Contains base NixOS configuration
* nix/includes - Contains reusable nix modules that are included in machine configs
* nix/machines - Contains per-physical-machine configs for user's NixOS systems
* nix/hardware - Each machine's hardware-configuration.nix, checked in by bin/install_nix
* home/ - Dotfiles symlinked to user's home directory.
* home-files/ - Dotfiles copied to the user's home directory.
* hooks/ - Scripts executed after dotfiles are installed

## The Two Install Scripts

### `bin/install_nix` — NixOS Config Deployment

**Purpose**: Copy local NixOS configuration from `nix/` into `/etc/nixos`, then
optionally rebuild the system.

**Critical detail**: This script does **not** run `nix build`, `nix flake`, or
`nixos-rebuild` directly from the source tree. It **copies** files to
`/etc/nixos` first, then runs `nixos-rebuild` from there. This is because
NixOS's `nixos-rebuild` expects its config at `/etc/nixos/` by default.

Before copying, it syncs the machine's `/etc/nixos/hardware-configuration.nix`
with `nix/hardware/<host>.nix`: the `/etc/nixos` copy replaces the repo copy
when that is missing or different, and is restored from the repo when it is
missing. The flake builds with the repo copy when there is one.

---

### `bin/install_dotfiles` — Home Directory Setup

**Purpose**: Install dotfiles from `home/` and `home-files/` (and optional
private directories) into the user's `$HOME`.

**Key design**: Layered installation with "last-write-wins" semantics. Base
dotfiles come from `home/` and `home-files/`, then private directories are
layered on top.

## Common Pitfalls

1. **Running Nix commands from the repo checkout**: `nixos-rebuild`,
   `nix build .#`, `nix flake update` — these will **not work** unless you
   first copy configs to `/etc/nixos`. Always use `bin/install_nix` or manually
   replicate the copy step.
