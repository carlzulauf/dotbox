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
│   │   ├── gnome-hidpi.nix # HiDPI / fractional scaling for GNOME
│   │   ├── gnome-niri.nix  # Niri compositor integration
│   │   ├── ai.nix          # Ollama, Open WebUI, LLM agents
│   │   ├── gaming.nix      # Steam, discord, lutris, gamescope
│   │   ├── printing.nix    # CUPS + Brother laser printer drivers
│   │   └── tv.nix          # TV/media machine config
│   ├── machines/           # Per-host machine configs
│   │   ├── frix.nix        # Framework Desktop (Ryzen AI Max)
│   │   ├── enix.nix        # HP Envy laptop
│   │   ├── nixd.nix        # Custom desktop (Ryzen 3700X)
│   │   ├── nax.nix         # NAS / remote build host
│   │   ├── xps.nix         # Work XPS laptop
│   │   ├── khoa.nix        # Torrent station
│   │   ├── phx.nix         # GPD WinMax handheld
│   │   ├── xtv.nix         # TV gaming machine
│   │   ├── obak.nix        # Offsite backup server
│   │   └── lb.nix          # (load balancer?)
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
│   │   ├── Code/User/settings.json
│   │   └── Code - OSS/User/settings.json
│   └── .local/bin/         # ~15 small utility scripts
├── home-files/             # Dotfiles installed as COPIES (for flatpak compat)
│   └── .var/app/...        # Chrome flatpak config
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

**Step-by-step flow**:

1. **Copy files** (with `sudo` unless `--no-use-sudo`):
   - `configuration.nix` → `/etc/nixos/configuration.nix`
   - `flake.nix` → `/etc/nixos/flake.nix`
   - `flake.lock` → `/etc/nixos/flake.lock`
   - `includes/` → `/etc/nixos/includes/` (via `rsync --archive`)
   - `machines/` → `/etc/nixos/machines/` (via `rsync --archive`)
   - `pkgs/` → `/etc/nixos/pkgs/` (via `rsync --archive`, if present)

2. **Upgrade** (if `--upgrade`/`--update`):
   - Runs `nix flake update --flake /etc/nixos` (with sudo)

3. **Rebuild** (if `--rebuild`, `--switch`, `--boot`, `--nax`, `--upgrade`):
   - Runs `nixos-rebuild` with the chosen mode (`boot` or `switch`)
   - Optionally passes `--build-host` for remote building

4. **Sync flake.lock back** — After a successful rebuild, the updated
   `flake.lock` is copied back to `nix/flake.lock` in the dotbox source tree,
   keeping version control in sync.

**Key flags**:
| Flag | Effect |
|------|--------|
| `--switch` / `-s` | Rebuild + switch to new generation immediately |
| `--boot` / `-b` | Build for next boot (default) |
| `--upgrade` / `-u` | Update flake.lock then rebuild |
| `--rebuild` / `-r` | Rebuild without updating |
| `--no-rebuild` | Copy configs only, no rebuild |
| `--nax` | Build remotely on nax host |
| `--build-host=HOST` | Build on arbitrary remote host |

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

**Step-by-step flow**:

1. **Discover changes** — Scans all source directories in order (base first,
   then private dirs). For each file, determines what action is needed:
   - `✓` — No change (symlink target matches or md5 matches)
   - `⊕` — Create new symlink
   - `+` — Create new file copy
   - `⇄` — Overwrite existing file (backup old one first)
   - `↺` — Update symlink target
   - `⊠` — Remove broken symlink
   - `∅` — Skip (optional file whose parent dir doesn't exist)

2. **Confirm** — Asks for confirmation before applying any changes.

3. **Apply** — Executes the actions: creates symlinks, copies files, backs up
   originals to `~/.backup-dotfiles`.

4. **Run hooks** — Executes every executable found in `hooks/`, `../dotbox-private/hooks/`,
   and `private-hooks/` directories.

**Source directory layering** (in order):
1. `dotbox/home/` — symlinks
2. `dotbox/home-files/` — copies
3. `dotbox/optional/` — symlinks (skipped if parent dir missing)
4. `dotbox/optional-files/` — copies (skipped if parent dir missing)
5. `../dotbox-private/home/` — private symlinks (overrides)
6. `../dotbox-private/home-files/` — private copies (overrides)
7. `../dotbox-private/optional/` — private optional symlinks
8. `../dotbox-private/optional-files/` — private optional copies
9. `dotbox/private/` — local private dir (gitignored)
10. `dotbox/private-files/` — local private copies dir (gitignored)

**`home/` vs `home-files/`**:
- `home/` — files installed as **symlinks**. Edits to the symlink reflect back
  to the repo. Good for most configs.
- `home-files/` — files installed as **copies**. Needed when the consuming app
  (e.g., Chrome flatpak) can't follow symlinks. The installer checks md5 hashes
  on reinstall; if the installed copy diverges from source, it's backed up and
  replaced.

**Agent warning**: The installer always runs from the dotbox root directory
(`File.join(__dir__, "..")`). When adding new dotfiles, place them in either
`home/` or `home-files/` depending on whether symlinks work for that app. Do
not place files directly in `~/.config/` or `~/.local/bin/` without also
adding them to the installer source tree, or they'll be overwritten on the
next install.

---

## Nix Flake Architecture

The flake (`nix/flake.nix`) defines **9 active hosts** in the `activeHosts` list.
Each host gets a NixOS configuration built from:

```
./configuration.nix
./includes/defaults.nix
./includes/carl.nix
./machines/${host}.nix
+ puma-dev (if frix)
+ ds4 (if frix)
+ home-manager with ./includes/home.nix for user carl
```

### Host-specific includes

Machines import relevant includes in their `.nix` files. For example,
`machines/frix.nix` imports:
- `ai.nix` — Ollama + Open WebUI
- `gui.nix` — Browsers, flatpak, vscodium
- `gnome.nix` — GNOME desktop
- `gnome-hidpi.nix` — Fractional scaling
- `gnome-niri.nix` — Niri compositor
- `dev.nix` — Development tools
- `printing.nix` — Printer support

While `machines/nixd.nix` imports a similar set (minus gnome-niri, plus gaming).

### Home Manager

Home manager config lives in `nix/includes/home.nix` and is applied to user
`carl` on every host. It currently configures tmux. The `flake.nix` wires it
up as:

```nix
home-manager.users.carl = ./includes/home.nix;
```

Machine-specific home-manager overrides are possible — `gui.nix` shows a pattern
where it adds vscodium config inside a `home-manager.users.carl` block scoped to
that machine's module.

### Important conventions

- **`nixpkgs-master`** is passed as a `specialArg` to every machine config,
  giving access to bleeding-edge packages (e.g., `nixpkgs-master.claude-code`).
- **`nixpkgs-omnissa`** is a fork pinned to the omnissa-horizon-client fix.
- **`llm-agents`** provides claude-code, pi, opencode, agent-browser.
- Machine configs use `lib.mkDefault` / `lib.mkForce` for safe overrides.
- The flake uses `nixpkgs.lib.genAttrs activeHosts mkHost` to generate all
  configurations from one function.

---

## Dotfile Layering (`home/` vs `home-files/`)

| Directory | Install method | Use case |
|-----------|---------------|----------|
| `home/` | Symlink | Most configs (fish, gitconfig, tmux, ghostty, starship, vscode settings, bin scripts) |
| `home-files/` | Copy | Flatpak apps that can't follow symlinks (e.g., Chrome flatpak flags) |

The installer scans both directories. Private directories (gitignored) follow
the same convention: `private/home/` → symlinks, `private/home-files/` → copies.

**For agents**: If you need to add a new config file:
- Place it in `home/` if it's for a terminal app or anything that reads
  symlinks without issue.
- Place it in `home-files/` only if the consuming app is a flatpak that
  resolves paths inside a sandbox where symlinks break (Chrome, Chromium,
  Electron apps in flatpak).

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

2. **Modifying dotfiles in `$HOME` instead of the source tree**: If you edit
   `~/.config/starship.toml` directly, the next `bin/install_dotfiles` will
   detect a mismatch and replace your changes. Always edit the source file in
   `home/` or `home-files/` and re-run the installer.

3. **Forgetting to sync flake.lock**: After a successful rebuild,
   `bin/install_nix` copies `flake.lock` back to `nix/flake.lock`. If you
   interrupt the process or do a manual rebuild, you must copy the lockfile
   back yourself or git will show a dirty tree.

4. **Missing private directories**: The installer looks for `private/` and
   `../dotbox-private/`. If you add a private directory that doesn't exist,
   the installer silently skips it. Create the directory structure matching
   `home/` or `home-files/` conventions.

5. **Adding machine configs**: To add a new host, append its hostname to
   `activeHosts` in `nix/flake.nix` and create `nix/machines/{hostname}.nix`.
   The hostname must match the output of `hostname` on the target machine.

6. **Remote building**: `--nax` or `--build-host` lets you build on a remote
   machine (typically `nax`, the NAS). This is essential for low-RAM machines
   or laptops during battery use. The remote builder must accept the Nix remote
   builder protocol.

7. **Home Manager in machine configs**: Machine-specific home-manager overrides
   should be placed in the machine's `.nix` file as a `home-manager.users.carl`
   block, not in `includes/home.nix`, which is shared across all hosts.
