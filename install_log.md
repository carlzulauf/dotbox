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

Adding tmux to host

```
sudo apt install tmux
```

Clean up apt so it stops complaining

```
sudo apt auto-remote
```

What happens if the prompt is installed in a distrobox?

Answer: terrible things. Starship's init script tries to use absolute path to starship.

Basic shell setup might be needed in both the host and distro boxes.

What happens if we add `fish` to `arch`? Seems to pick up configs quite nicely.

```
arch:$ sudo pacman -S fish starship exa
# had to use sudo because otherwise got password prompt I can't solve
arch:$ sudo chsh -s /usr/sbin/fish carl
```

Let's give the host `exa` and `starship` as well.

```
# hoped this was user, but prompts for password
snap install starship
sudo apt install exa
```

Going to need some nerd fonts for `exa` icons to show up right.

Need keepass to get into github and make a public repo for this project

```
snap install keepassxc
```

Created and pushed to https://github.com/carlzulauf/dotbox/

Installed google chrome from flathub.

```
flatpak install flathub com.google.Chrome
```

Added dark mode flags for this flatpack to `.var/app/com.google.Chrome/config/chrome-flags.conf`.

Installed gnome extension manager and used that to install caffeine extension.

```
sudo apt install gnome-shell-extension-manager
```
## Fedora Silverblue

I think I'm starting to get an idea of how this works and want to jump in with both feet. Or, maybe like wade in slowly instead of dipping my toes. I'm going to try a real immutable operating system, Fedora Silverblue. On real hardware, as the only operating system. We'll see if I stick with it.

I've nuked the existing garuda and ubuntu installs on my lenovo laptop. I backed them up first so not totally nuked. I mostly did this because I couldn't get the fedora installer to play nice with the existing installs.

Here is what the backup looks like if you're wondering how to make a compressed drive image as fast as possible using all cores on your machine:

Obviously, replace `/dev/nvme0n1p1` with the actual device you want to backup and `/path/to/backup.img.lbzip2` with wherever you want the backup file to live. Requires `lbzip2` compression utility.

```
sudo dd status=progress bs=16M if=/dev/nvme0n1p1 | lbzip > /path/to/backup.img.lbzip2
```

Getting into Fedora Silverblue I'm kind of shocked at how many core gnome apps are flatpaks.

I followed the official user guide to enabling flathub, which involved going [here](https://flatpak.org/setup/Fedora), clicking the repo file link, and then opening it in the Gnome Software Center.

### The Plan

Going to try to lay out which packages I think should be flatpaks and which should be layered fedora packages.

#### Flatpak packages

Base

```
com.github.tchx84.Flatseal
com.mattjakeman.ExtensionManager
com.google.Chrome
org.keepassxc.KeePassXC
org.pulseaudio.pavucontrol
com.github.zocker_160.SyncThingy
org.gimp.GIMP
org.inkscape.Inkscape
org.signal.Signal
org.videolan.VLC
com.transmissionbt.Transmission
com.github.jeromerobert.pdfarranger
```

I'd like to also try these gnome apps

```
org.gnome.Epiphany
com.github.maoschanz.drawing
com.github.hugolabe.Wike
com.github.liferooter.textpieces
```

Video

```
com.obsproject.Studio
org.kde.kdenlive
us.zoom.Zoom
fr.handbrake.ghb
org.pitivi.Pitivi
org.gnome.Cheese
```

Dev

```
io.atom.Atom
com.visualstudio.code-oss
com.visualstudio.code
com.sublimetext.three
org.kde.umbrello
org.gaphor.Gaphor
com.github.alecaddd.sequeler
org.sqlitebrowser.sqlitebrowser
org.gnome.Boxes
```

Gaming

```
com.valvesoftware.Steam
com.mojang.Minecraft
com.discordapp.Discord
```

#### Layered packages

```
fish
exa
tmux
starship
lbzip2
direnv
gparted
gnome-tweaks
ruby?
```

### Actually Installing Things

Time to see if this is going to work. Going to need to install distrobox to have ruby as I'm not sure I want to layer that. But, first, a restart.

Still gnome 42. Darn. Gnome 43 has some nice upgrades and some of the apps are updated, but not the core. Oh well. Might end up dual booting garuda or ubuntu 22.10 after all.

Installed flatseal and extension manager by hand through software center. Used extension manager to install app indicator, caffeine, and ddterm gnome extensions.

Installing just vscode flatpak to provide a base editor to migrate more of my dotfiles.

```
flatpak install flathub com.visualstudio.code-oss
```

While waiting for that, kicking off the distrobox install and creating an arch box.

```
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
distrobox create -i archlinux arch-shell
```

Going to install some things that almost certainly need to be layered packages.

```
rpm-ostree install gnome-tweaks fish exa tmux lbzip2 direnv gparted
```

Reboot again.

vs-code was showing in light mode. Tried setting `GTK_THEME=Adwaita-dark` env variable. Tried using gnome-tweaks to turn on `Adwaita-dark` for legacy apps (darkened title bar). Menus were still light until I finally installed `Adwaita-dark` flatpak. S.O. answers, fedora docs, flatpak dark mode guides... none of them suggested this. Found this in the flathub package maintainers guide. Ridiculously hard to figure out.

```
flatpak install flathub org.gtk.Gtk3theme.Adwaita-dark
```

Try to get ruby and some other stuff working in arch-shell

```
distrobox enter arch-shell
as:$ sudo pacman -S which neofetch fish sysstat bind nano ruby ruby-webrick ruby-pry ruby-docs
as:$ gem install redis
```

Last command installed gem into home folder shared by host, so visible in `~/.local/share/gem/ruby/3.0.0`.

Still can't run dotbox installer cause no ruby on host. Exporting ruby from arch-shell.

```
as:$ distrobox-export --bin /usr/sbin/ruby --export-path ~/.local/bin
as:$ distrobox-export --bin /usr/sbin/pry --export-path ~/.local/bin
```

Install script seemed to work (after a fix), but all the symlinks are to `/var/home/carl` which doesn't work from host. Might have to layer a system ruby?

```
rm ~/.local/bin/ruby
rm ~/.local/bin/pry
rpm-ostree install ruby
```

Reboot again. But, beforehand lets install a critical flatpaks so they are waiting for us and we can listen to youtube while washing dishes.

```
flatpak install flathub com.google.Chrome org.keepassxc.KeePassXC org.pulseaudio.pavucontrol com.github.zocker_160.SyncThingy org.gimp.GIMP org.inkscape.Inkscape org.signal.Signal org.videolan.VLC com.transmissionbt.Transmission com.github.jeromerobert.pdfarranger
```

Oh my that's a lot of disk space for the prerequisites. Guess I'm still using only 14GB of main partition so, whatever.

Chrome works. Dark mode required replacing the chrome flags symlink with a real file. I think flatpak configs are going to require copying over real files, not symlinks. This means modifying the installer script. Whew, that took a while..

Checked out fish first and discovered a couple copypasta issues in config. Updated.

To have starship as my prompt I'm going to have to layer that too. Another reboot. I'm being punished for layering packages. Maybe that's good?

```
rpm-ostree install starship
```

Lots of icons aren't showing up right in exa and starship. Also, starship appears to be out of date as it's complaining about my 'container' config stanza.

Added some nerd fonts to my `dotbox-private` repo since I'm not sure about re-distributing those and also don't want to put any big blobs in this repo if it's avoidable. I feel like fonts are also a deeply personal configuration. Maybe a lot of things this repo will configure by default belong in the camp of deeply personal, but I'm not ready to have fonts constitute the vast majority of bytes in this repo. That would definitely be the case with only a few of my favorite fonts added.

Had to reboot again to get font selectors to see the fonts I put into `~/.local/share/fonts`.

`chsh` isn't present so changed my shell to fish using `lchsh`, which appears to be the silverblue way.

```
sudo lchsh carl
```

Let's get fish+starship on arch. Fish installed previously. Using `chsh` to change it to fish. Also install starship.

```
distrobox enter arch-shell
as:$ sudo chsh carl # change to /usr/sbin/fish
as:$ sudo pacman -S starship
```

That was pretty easy.

Time to try setting up asdf. Maybe we should use a separate distrobox for that? Going to start by cloing from this one and see.

Started by cloning `arch-shell` distrobox into a new box: `arch-asdf`. Then, `yay` and try to install `asdf`.

```
distrobox create --name arch-asdf --clone arch-shell
distrobox enter arch-asdf
aa:$ sudo pacman -S --needed git base-devel openssh
aa:$ git clone https://aur.archlinux.org/yay.git
aa:$ cd yay
aa:$ makepkg -si
as:$ yay -S asdf-vm
```

Added fish config hook. Restarted arch-asdf session to check install. Seems to work. Installing ruby and node versions based on ssms.

```
asdf plugin add ruby
asdf plugin add nodejs
asdf install ruby 3.1.2
asdf install nodejs 14.21.1
# testing with a live app
cd projects/spreadsheet_sms
asdf local ruby 3.1.2
asdf local ruby 14.21.1
bundle install # fails because no pg lib (pqdev)
```
