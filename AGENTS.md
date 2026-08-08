# Dotbox — Agent Guide

This document is a reference for AI agents (or human collaborators) working on the
**dotbox** repository. It explains the architecture, the deployment pipeline, and
the conventions that agents must follow to avoid breaking things.

---

## Table of Contents

1. [Repository Layout](#repository-layout)
2. [The Two Install Scripts](#the-two-install-scripts)
   - [`bin/install_nix`](#bininstall_nix--nixos-config-deployment)
   - [`bin/install_dotfiles`](#bininstall_dotfiles--home-directory-setup)
3. [Nix Flake Architecture](#nix-flake-architecture)
4. [Dotfile Layering (home/ vs home-files/)](#dotfile-layering-home-vs-home-files)
5. [Hooks](#hooks)
6. [Common Pitfalls](#common-pitfalls)

---

## Repository Layout

```
dotbox/
├── bin/
│   ├── install_nix         # Deploy NixOS config → /etc/nixos
│   └── install_dotfiles    # Install dotfiles → $HOME
├── nix/
│   ├── flake.nix           # Flake entry point; defines all machine outputs
│   ├── flake.lock          # Pinned nixpkgs inputs
│   ├── configuration.nix   # Base system config (global, applied to all hosts)
│   ├── includes/           # Reusable NixOS modules
│   │   ├── defaults.nix    # Global settings (fish, nix-ld, env vars)
│   │   ├── carl.nix        # User account, syncthing, sudo rules
│   │   ├── dev.nix         # Dev tools (editors, SQL clients, zoom)
│   │   ├── gui.nix         # GUI apps, browsers, flatpak, vscodium
│   │   ├── gnome.nix       # GNOME desktop, extensions, libvirtd
│   │   ├── gnome-cosmic.nix # Cosmic desktop alongside GNOME (selectable at GDM)
│   │   ├── gnome-niri.nix  # Niri compositor alongside GNOME — UNUSED, no host imports it
│   │   ├── ai.nix          # Ollama, Open WebUI
│   │   ├── gaming.nix      # Steam, discord, lutris, gamescope
│   │   ├── printing.nix    # CUPS + Brother laser printer drivers
│   │   └── tv.nix          # TV/media machine config (idle-blank workaround, cockpit)
│   ├── machines/           # Per-host machine configs
│   │   ├── generic.nix     # Base host for initial installs (no hardware config)
│   │   ├── frix.nix        # Framework Desktop (Ryzen AI Max)
│   │   ├── enix.nix        # HP Envy laptop
│   │   ├── nixd.nix        # Custom desktop (Ryzen 3700X)
│   │   ├── nax.nix         # NAS / remote build host
│   │   ├── xps.nix         # Work XPS laptop
│   │   ├── khoa.nix        # Torrent station
│   │   ├── phx.nix         # GPD WinMax handheld
│   │   ├── xtv.nix         # TV gaming machine
│   │   ├── obak.nix        # Offsite backup server
│   │   └── lb.nix          # INACTIVE — Lenovo IdeaPad (not in activeHosts)
│   └── README.md
├── home/                   # Dotfiles installed as SYMLINKS
│   ├── .gitconfig
│   ├── .tmux.conf
│   ├── .pryrc
│   ├── .irbrc
│   ├── .config/
│   │   ├── starship.toml
│   │   ├── fish/conf.d/*.fish
│   │   ├── ghostty/config
│   │   ├── chrome-flags.conf
│   │   ├── tproj.yml
│   │   ├── fastfetch/config.jsonc
│   │   ├── Code/User/settings.json
│   │   ├── Code/User/snippets/erb.json
│   │   ├── Code/User/snippets/ruby.json
│   │   ├── Code - OSS/User/settings.json
│   │   ├── Code - OSS/User/snippets/erb.json
│   │   └── Code - OSS/User/snippets/ruby.json
│   ├── .local/bin/         # ~20 small utility scripts
│   └── .var/app/           # Flatpak vscode settings (symlinked)
├── home-files/             # Dotfiles installed as COPIES (for flatpak compat)
│   └── .var/app/com.google.Chrome/config/chrome-flags.conf
├── hooks/                  # Post-install hooks (run by install_dotfiles)
│   └── always_on_top_keyboard_shortcut
├── docs/                   # Templates (e.g., redis-box.conf.erb)
└── README.md
```

---

## The Two Install Scripts

### `bin/install_nix` — NixOS Config Deployment

**Purpose**: Copy local NixOS configuration from `nix/` into `/etc/nixos`, then
optionally rebuild the system.

**Critical detail**: This script does **not** run `nix build`, `nix flake`, or
`nixos-rebuild` directly from the source tree. It **copies** files to
`/etc/nixos` first, then runs `nixos-rebuild` from there. This is because
NixOS's `nixos-rebuild` expects its config at `/etc/nixos/` by default.

**Key flags**:
| Flag | Effect |
|------|--------|
| `--switch` / `-s` | Rebuild + switch to new generation immediately |
| `--boot` / `-b` | Rebuild for next boot (default) |
| `--upgrade` / `-u` | Update flake.lock then rebuild |
| `--rebuild` / `-r` | Rebuild without updating |
| `--no-rebuild` | Disable rebuild (overrides other flags) |
| `--nax` | Build remotely on nax host |
| `--build-host=HOST` | Build on arbitrary remote host |
| `--hostname` | Specify machine to build (default: `hostname`) |
| `--no-use-sudo` | Skip sudo for copy operations |

**⚠️ Agent warning**: Never run `nix build`, `nix flake`, or `nixos-rebuild`
directly from the `nix/` directory. Inform the user to run `bin/install_nix`, or
replicate its copy-then-rebuild pattern. The flake is designed to be evaluated
from `/etc/nixos`, not from the repo checkout.

---

### `bin/install_dotfiles` — Home Directory Setup

**Purpose**: Install dotfiles from `home/` and `home-files/` (and optional
private directories) into the user's `$HOME`.

**Key design**: Layered installation with "last-write-wins" semantics. Base
dotfiles come from `home/` and `home-files/`, then private directories are
layered on top.

**`home/` vs `home-files/`**:
- `home/` — files installed as **symlinks**. Edits to the symlink reflect back
  to the repo. Good for most configs.
- `home-files/` — files installed as **copies**. Needed when the consuming app
  (e.g., Chrome flatpak) can't follow symlinks. The installer checks md5 hashes
  on reinstall; if the installed copy diverges from source, it's backed up and
  replaced.

---

## Nix Flake Architecture

The flake (`nix/flake.nix`) defines **10 active hosts** in the `activeHosts` list
(`lb` is excluded — its machine config exists but is inactive). Each host gets a
NixOS configuration built from:

```
./configuration.nix
./includes/defaults.nix
./includes/carl.nix
./machines/${host}.nix
puma-dev.nixosModules.puma-dev   (all hosts)
ds4.nixosModules.ds4             (all hosts)
```

### Flake inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` (nixos-unstable) | Primary package set |
| `nixpkgs-master` (master) | Bleeding-edge packages (claude-code, pi, opencode, etc.) |
| `nixos-hardware` | Hardware-specific NixOS modules |
| `puma-dev` | Local puma-dev proxy service (used on frix, xps) |
| `ds4` | DwarfStar (DeepSeek v4) inference service (frix only) |

Commented-out inputs (not currently active): `nixpkgs-omnissa` (PR merged
upstream, no longer needed), `hermes-agent`, `nix-openclaw`.

Removed inputs: `llm-agents` — the LLM CLI tools (claude-code, agent-browser)
now come from `nixpkgs-master` instead.

### specialArgs

Every machine config receives these extra arguments:
- `nixpkgs-master` — imported with `allowUnfree = true`

### Host-specific includes

Machines import relevant includes in their `.nix` files:

| Host | Includes |
|------|----------|
| **generic** | gui, gnome |
| **frix** | ai, gui, gnome, gnome-cosmic, dev, printing |
| **enix** | gui, printing, gnome, gnome-cosmic |
| **nixd** | ai, gui, gnome, gaming, printing |
| **xps** | gui, dev, ai, gaming, gnome, printing |
| **khoa** | gui, printing |
| **phx** | gui, gnome, gaming, dev, printing |
| **xtv** | ai, gui, tv, gaming, printing |
| **nax** | ai, gui, tv |
| **obak** | gui, tv |
| *lb (inactive)* | gui, gnome, gaming, printing |

### Important conventions

- **`nixpkgs-master`** is passed as a `specialArg` to every machine config,
  giving access to bleeding-edge packages (e.g., `nixpkgs-master.claude-code`).
- `nixpkgs-omnissa` input has been removed — the omnissa-horizon-client tile-font
  fix landed upstream, so it now comes from regular `pkgs`.
- Machine configs use `lib.mkDefault` / `lib.mkForce` for safe overrides.
- The flake uses `nixpkgs.lib.genAttrs activeHosts mkHost` to generate all
  configurations from one function.
- `puma-dev` and `ds4` modules are included for **all** hosts, but only specific
  machines enable their respective services (frix and xps for puma-dev; frix
  only for ds4).

---

## Dotfile Layering (`home/` vs `home-files/`)

| Directory | Install method | Use case |
|-----------|---------------|----------|
| `home/` | Symlink | Most configs (fish, gitconfig, tmux, ghostty, starship, vscode settings, bin scripts, flatpak vscode settings) |
| `home-files/` | Copy | Apps that can't follow symlinks (e.g., Chrome flatpak flags) |

The installer scans both directories. Private directories (gitignored) follow
the same convention: `private/home/` → symlinks, `private/home-files/` → copies.

---

## Hooks

The `hooks/` directory contains executables run **after** dotfile installation.
Current hooks:

- **`always_on_top_keyboard_shortcut`** — Sets Ctrl+Super+T as the "always on
  top" shortcut in GNOME via `gsettings`.

Hooks are also searched in `../dotbox-private/hooks/` and `private-hooks/`.
Hooks can be skipped with `--no-hooks`.

---

## Common Pitfalls

1. **Running Nix commands from the repo checkout**: `nixos-rebuild`,
   `nix build .#`, `nix flake update` — these will **not work** unless you
   first copy configs to `/etc/nixos`. Always use `bin/install_nix` or manually
   replicate the copy step.

2. **Adding machine configs**: To add a new host, append its hostname to
   `activeHosts` in `nix/flake.nix` and create `nix/machines/{hostname}.nix`.
   The hostname must match the output of `hostname` on the target machine.
   If a machine config exists (`lb.nix`) but is not in `activeHosts`, it is
   inert — it won't be built by any `nixos-rebuild`.

3. **Remote building**: `--nax` or `--build-host` lets you build on a remote
   machine (typically `nax`, the NAS). This is essential for low-RAM machines
   or laptops during battery use. The remote builder must accept the Nix remote
   builder protocol.

4. **No Home Manager**: this repo manages dotfiles itself via
   `bin/install_dotfiles` (`home/` and `home-files/`). Don't reach for
   `home-manager.users.carl` blocks — put user-facing config in `home/`, and
   packages in `environment.systemPackages`.
