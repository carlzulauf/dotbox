# NixOS Configuration Repository

This repository manages infrastructure for multiple NixOS systems (desktops, laptops, servers) using **Nix Flakes**. It utilizes a shared configuration structure with machine-specific overrides and host-level home-manager integration.

## 🏗️ Architecture

### Directory Structure (`nix/`)
*   **`flake.nix`**: The entry point defining all outputs. It iterates over the `activeHosts` list to generate configurations for each machine.
*   **`configuration.nix`**: The base system configuration applied to all hosts (e.g., global Nix settings, SSH defaults).
*   **`machines/`**: Contains host-specific configurations (`{hostname}.nix`). These files handle hardware-specific drivers, storage mounts, and service toggles.
*   **`includes/`**: Reusable modules for shared features:
    *   `defaults.nix`: Global settings (fish shell, network-manager, nix-ld).
    *   `carl.nix`: User account setup and service credentials (Syncthing, etc.).
    *   `dev.nix`, `gui.nix`, `gnome.nix`: Feature sets for different usage profiles.

### The Installer (`bin/install_nix`)
The script `bin/install_nix` automates the deployment process:
1.  Copies local configuration files (`configuration.nix`, `includes/`) to `/etc/nixos`.
2.  Handles flake updates via `nix flake update`.
3.  Triggers the rebuild using `nixos-rebuild` (in switch or boot mode).
4.  Syncs the resulting `flake.lock` back to the config directory for version control stability.

## 🖥️ Supported Hosts

The `flake.nix` defines the following active systems:

| Host | Description | Key Config Notes |
| :--- | :--- | :--- |
| **frix** | Framework Desktop (AMD Ryzen 9) | Ollama/ROCm support; GNOME + Niri. |
| **enix** | HP Envy Laptop | |
| **khoa** | Torrent Station | |
| **nax** | NAS & Remote Builder | Used as a build host for faster derivation evaluation on larger machines. |
| **nixd** | Custom Desktop | |
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
The configuration unifies the environment across all hosts using **Home Manager**.
*   **Default Shell**: Fish is set globally.
*   **Nix Store**: Auto-optimisation and binary substituters (cache.numtide) are enabled by default.
*   **Development**: Ruby, Node.js, SQL tools, and Terraform are pre-bundled in system packages (`includes/defaults.nix`).

## 💡 Configuration Tips
*   **Home Manager**: User-level configuration is split between the global `home-manager.users.carl` definition (in `flake.nix`) and specific module definitions.
*   **Kernels**: Hardware-specific kernel pinning is handled in individual machine files (e.g., `machines/frix.nix`).
*   **Unfree Packages**: The config explicitly allows unfree software for things like Electron, Zoom, and GIMP (`allowed := ["pulsar" "electron"...]`).
