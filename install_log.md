# Install Log

My attempts to actually setup a workable dev environment without my old dotfiles and using the new containers-preferred approach.

## Ubuntu 22.04

Ok, not an immutable OS, but I'm going to try to treat it like one for my first real attempt. Silverblue is fun and all but it's installer kinda sucks. Getting dual booting and some gaming stuff working seemed easier in Ubuntu.

### Setup

Shrunk the existing garuda partition on my lenovo laptop. Btrfs so this involved online shrinking of the btrfs filesystem, then re-creating the partition (smaller) using fdisk. It was a first.

Manually created a new partition using ubuntu's installer. btrfs format. / mount point. That should be all we need.

Ubuntu's grub install won't see garuda for some reason. I guess I'll fix that later.

Ubuntu is booting. Let's go.

### Post Install

There is no git so I'm taking notes without revision tracking. Adding that first.

```
sudo apt install git
```

Initialized git on this dir. Warned me it's using `master`. Changed the default and some other config and moved to `main`.

```
git config --global init.defaultBranch main
git config --global user.email my@email.com
git config --global user.name "My Name"
git checkout -b main
```

Install flatpak+flathub.

```
sudo apt install flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

**restart**

Install distrobox in home dir.

```
sudo apt install curl
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
```

**restart again** so `~/.local/bin` is loaded.

Install VS Code via snap package

```
sudo snap install --classic code
```

Install podman so distrobox will work.

```
sudo apt install podman
```

Create first distrobox for arch:

```
distrobox create --image docker.io/library/archlinux --name arch
```

Install `yay`

```
distrobox enter arch
arch:$ sudo pacman -S --needed git base-devel
arch:$ git clone https://aur.archlinux.org/yay.git
arch:$ cd yay
arch:$ makepkg -si
```

Install `ruby` and `pry` in arch and export `pry`

```
distrobox enter arch
arch:$ pacman -S ruby ruby-pry ruby-webrick
```

Decided to install a system ruby in ubuntu as well. I think that will still be a prereq for dotfiles to work.

```
sudo apt install ruby
```

Pry will only come from arch though

```
distrobox enter arch
arch:$ distrobox-export --bin /usr/sbin/pry --export-path ~/.local/bin
```

Seems to work :-)

Installed redis gem in arch distrobox and it works in pry inside and outside the box.

```
arch:$ gem install redis
```

The host should probably have `fish` as well. I've thought about putting it exclusively in a distrobox, but I don't know what effect a different shell on the host will even have. Maybe I should try that first?

```
sudo apt install fish
chsh # => /usr/bin/fish
```

Restarted to make it active. Saw the same swapfile error I've been seeing on boot for a while.

Did some searching. Looks like maybe Ubuntu isn't setting up a swapfile on btrfs properly?

Found [these arch instructions](https://superuser.com/a/1531207) that work great for Ubuntu as well.

```
# truncate -s 0 /swapfile
# chattr +C /swapfile
# btrfs property set /swapfile compression none
# fallocate -l 2G /swapfile
# chmod 600 /swapfile
# mkswap /swapfile
# swapon /swapfile
```

Yep, ubuntu just didn't setup the file right.

Fish can't see distrobox because it's not loading `~/.local/bin`.

This makes the install script priority #1. It will be based on the original `Rakefile` but be an executable ruby shell script instead: `bin/install`.

For now it will just install fish configs.

```
chmod +x bin/install
bin/install
```
