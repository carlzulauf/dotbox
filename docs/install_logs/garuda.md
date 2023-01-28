# Garuda Linux

Yeah, all that fedora silverblue stuff is well and good and works pretty well, but silverblue has some issues. Like the rest of fedora they've decided to cower to their own theoretical arguments when it comes to the legality of including hardware decoding for h265 on AMD hardware. I sometimes think IBM/RedHat just likes to kneecap Fedora a bit. I'm not going to build a custom kernel or deal with shitty battery life watching youtube.

Going back to Garuda. This time I'm going to treat it like an immutable OS and try to lean heavy on flatpaks.

The AUR is enabled by default. That gives me pause for this being a super stable system. May be the only reasonable way to get Gnome 43 and full tablet/touchscreen/rotation support on my HP Envy right now. Proceeding.

## Host OS Install Log

Zen kernel works in installer, but after updating it breaks wifi. Installed the AMD specific kernel and that seems to work. Installed a couple others as backups.

```
sudo pacman -Syu linux-amd linux-amd-headers linux-mainline linux-mainline-headers linux-lts linux-lts-headers
```

Installed a basic set of tools for the host OS.

```
sudo pacman -Syu code firefox signal-desktop tmux direnv sysstat ruby ruby-pry ruby-docs ruby-webrick ttf-ubuntu-mono-nerd podman podman-docker podman-compose
chsh # change login shell to /usr/bin/fish
```

*restart*

Installing google chrome from chaotic-aur via `paru` AUR helper included in garuda.

```
paru -S google-chrome
```

Installed Gnome Extension Manager (chaotic-aur) and used that to install the extensions: Caffeine, AppIndicator and KStatusNotifierItem Support, ddterm, Removable Drive Menu. The Pamac Updates Indicator was already installed, so I enabled it.

## Distrobox Setup

Getting podman setup for userland operation, installing distrobox, and getting a distrobox with basic shell tools and asdf for development.

```
sudo usermod --add-subuids 100000-199999 --add-subgids 100000-199999 carl
podman system migrate
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
distrobox create -i archlinux arch-shell
distrobox enter arch-shell
as:$ sudo pacman -S base-devel which neofetch sysstat smartmontools iotop bind nano ruby ruby-pry ruby-docs starship git man-db
```