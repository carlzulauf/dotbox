# NixOS Configuration Repository

This repository manages infrastructure for multiple NixOS systems (desktops, laptops, servers) using **Nix Flakes**. It utilizes a shared configuration structure with machine-specific overrides.

## 🏗️ Architecture

### Directory Structure (`nix/`)
*   **`flake.nix`**: The entry point defining all outputs. It generates a configuration for every `machines/{hostname}.nix`.
*   **`configuration.nix`**: Base Nix settings applied to all hosts (the extra cache.numtide.com binary cache).
*   **`machines/`**: Contains host-specific configurations (`{hostname}.nix`). These files handle hardware-specific drivers, storage mounts, service toggles, and each host's `system.stateVersion`.
*   **`hardware/`**: Each host's generated `hardware-configuration.nix`, as `{hostname}.nix`. `bin/install_nix` checks these in from `/etc/nixos`; hosts without one (and `generic`) build with `/etc/nixos/hardware-configuration.nix`, which needs `--impure`.
*   **`includes/`**: Reusable modules for shared features:
    *   `defaults.nix`: Global settings (fish shell, network-manager, nix-ld, tailscale, openssh).
    *   `carl.nix`: User account setup and service credentials (Syncthing, etc.).
    *   `dev.nix`, `gui.nix`, `gnome.nix`, `ai.nix`, `gaming.nix`, `steam.nix`, `tv.nix`: Feature sets for different usage profiles.
    *   `remote-desktop-gnome.nix` (imported by `gnome.nix`) and `remote-desktop-plasma.nix` (imported by khoa): RDP over the tailnet on the standard port, 3389, sharing the logged-in live session only.
    *   `niri-dms.nix`: Standalone niri desktop riced with DankMaterialShell (bar, launcher, notifications, lock, theming) and its greetd greeter. Used by nirvm.

### The Installer (`bin/install_nix`)
The script `bin/install_nix` rebuilds straight from this directory (the flake only sees git-tracked files, so `git add` new ones):
1.  Copies this machine's `/etc/nixos/hardware-configuration.nix` to `hardware/{hostname}.nix` when that is missing or different (commit the result), and the same for its puma-dev CA cert in `puma-dev/`.
2.  Rebuilds with [nh](https://github.com/nix-community/nh) (`nh os switch` or `nh os boot`), as you, with sudo only for activation. With `--upgrade` it passes `--update`, so nh updates every flake input in `flake.lock` here first. `--no-rebuild` skips the update and rebuild, whatever else is passed.

3.  With `--gc`, runs `nh clean all` afterwards, keeping the host's `configurationLimit` generations (or `--gc=N` / `--gc=30d`; a tighter trim reinstalls the boot loader so no stale entries are left). A weekly `nh clean` timer does the same on every host.

Every command is printed before it runs. `programs.nh.flake` points at this directory, so plain `nh os switch` works too.

## 🖥️ Supported Hosts

The `flake.nix` defines a system for each file in `machines/`:

| Host | Description | Key Config Notes |
| :--- | :--- | :--- |
| **generic** | Base host for initial installs | No hardware-specific config. |
| **frix** | Framework Desktop (AMD Ryzen 9) | ds4 + Ollama, switchable ROCm/Vulkan backends; GNOME + COSMIC. |
| **enix** | HP Envy Laptop | |
| **khoa** | Torrent Station | |
| **nax** | NAS & Remote Builder | Used as a build host for faster derivation evaluation on larger machines. |
| **nixd** | Custom Desktop | |
| **nirvm** | niri VM (libvirt guest on frix) | niri + DankMaterialShell; created with `bin/nirvm create`, hand-written `hardware/nirvm.nix` also builds its disk image; VNC on 5900 via ReFrame. |
| **obak** | Offsite Backup Server | |
| **phx** | GPD WinMax (Handheld PC) | |
| **xps** | Work XPS Laptop | |
| **xtv** | TV / Media Device | |

## 🚀 Usage

### Installation & Deployment

To deploy the system configuration to a target machine:

```bash
# 1. Sync machine-local files (dry run - prints the rebuild commands)
bin/install_nix

# 2. Switch immediately to this generation
bin/install_nix --switch

# 3. Upgrade and build for next boot
bin/install_nix --boot --upgrade
```

**Remote Building**
For slower machines, ones with fewer resources, or with limited battery life, use a build server (like `nax`):

```bash
bin/install_nix --nax   # Shorthand for --build-host nax
```

### Managing Packages & Environment
The configuration unifies the environment across all hosts via `environment.systemPackages`; dotfiles are managed by `bin/install_dotfiles` from `home/` and `home-files/` rather than Home Manager.
*   **Default Shell**: Fish is set globally.
*   **Nix Store**: Auto-optimisation, a weekly `nh clean`, and binary substituters (cache.numtide) are enabled by default.
*   **Development**: Ruby, Node.js, Python, SQLite, and Terraform are pre-bundled in system packages (`includes/defaults.nix`).

## 💡 Configuration Tips
*   **User-level config**: There is no Home Manager. User-facing dotfiles live in `home/` (installed by `bin/install_dotfiles`) and user packages go in `environment.systemPackages`.
*   **Kernels**: Hardware-specific kernel pinning is handled in individual machine files (e.g., `machines/frix.nix`).
*   **Unfree Packages**: `allowUnfree` is on for every host (`includes/defaults.nix`).
*   **Insecure Packages**: Packages nixpkgs marks insecure must be named in `allowInsecurePredicate` in `includes/defaults.nix` (currently pulsar, beekeeper-studio, and ventoy).
