# NixOS Configuration Repository

This repository manages infrastructure for multiple NixOS systems (desktops, laptops, servers) using **Nix Flakes**. It utilizes a shared configuration structure with machine-specific overrides.

## 🏗️ Architecture

### Directory Structure (`nix/`)
*   **`flake.nix`**: The entry point defining all outputs. It iterates over the `activeHosts` list to generate configurations for each machine.
*   **`configuration.nix`**: Base Nix settings applied to all hosts (the extra cache.numtide.com binary cache).
*   **`machines/`**: Contains host-specific configurations (`{hostname}.nix`). These files handle hardware-specific drivers, storage mounts, service toggles, and each host's `system.stateVersion`.
*   **`hardware/`**: Each host's generated `hardware-configuration.nix`, as `{hostname}.nix`. `bin/install_nix` checks these in from `/etc/nixos`; hosts without one (and `generic`) build with `/etc/nixos/hardware-configuration.nix`.
*   **`includes/`**: Reusable modules for shared features:
    *   `defaults.nix`: Global settings (fish shell, network-manager, nix-ld, tailscale, openssh).
    *   `carl.nix`: User account setup and service credentials (Syncthing, etc.).
    *   `dev.nix`, `gui.nix`, `gnome.nix`, `ai.nix`, `gaming.nix`, `steam.nix`, `tv.nix`: Feature sets for different usage profiles.
    *   `remote-desktop-gnome.nix` (imported by `gnome.nix`) and `remote-desktop-plasma.nix` (imported by khoa): RDP over the tailnet. Port 3390 shares the live session, 3389 is GNOME Remote Login.
    *   `niri-dms.nix`: Standalone niri desktop riced with DankMaterialShell (bar, launcher, notifications, lock, theming) and its greetd greeter. Used by nirvm.

### The Installer (`bin/install_nix`)
The script `bin/install_nix` automates the deployment process:
1.  Syncs this machine's `/etc/nixos/hardware-configuration.nix` with `hardware/{hostname}.nix`. The `/etc/nixos` copy replaces the repo copy when that is missing or different (commit the result), and is restored from the repo when it is missing.
2.  Mirrors the whole `nix/` directory to `/etc/nixos`, deleting files that are no longer in the repo (except `hardware-configuration.nix`).
3.  With `--upgrade`, updates every flake input via `nix flake update`.
4.  Triggers the rebuild using `nixos-rebuild` (in switch or boot mode). `--no-rebuild` skips the update and rebuild, whatever else is passed.
5.  Syncs the resulting `flake.lock` back to the config directory for version control stability.

## 🖥️ Supported Hosts

The `flake.nix` defines the following active systems:

| Host | Description | Key Config Notes |
| :--- | :--- | :--- |
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
# 1. Copy configs (dry run - prints commands)
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
*   **Nix Store**: Auto-optimisation and binary substituters (cache.numtide) are enabled by default.
*   **Development**: Ruby, Node.js, Python, SQLite, and Terraform are pre-bundled in system packages (`includes/defaults.nix`).

## 💡 Configuration Tips
*   **User-level config**: There is no Home Manager. User-facing dotfiles live in `home/` (installed by `bin/install_dotfiles`) and user packages go in `environment.systemPackages`.
*   **Kernels**: Hardware-specific kernel pinning is handled in individual machine files (e.g., `machines/frix.nix`).
*   **Unfree Packages**: `allowUnfree` is on for every host (`includes/defaults.nix`).
*   **Insecure Packages**: Packages nixpkgs marks insecure must be named in `allowInsecurePredicate` in `includes/defaults.nix` (currently pulsar, beekeeper-studio, and ventoy).
