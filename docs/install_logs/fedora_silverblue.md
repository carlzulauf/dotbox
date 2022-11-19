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

Added fish config hook. Restarted arch-asdf session to check install. Seems to work. Installing ruby and node versions based on my spreadsheet_sms project.

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
sudo pacman -S postgresql-libs
bundle install # completed this time
# need a real database and cache to see if the app works end-to-end
sudo pacman -S postgresql redis

# no systemd running so have to start postgresql by hand. going to try with current user.

# initdb failed with missing locale. have to generate first.
sudo nano /etc/locale.gen # uncommented en_US line
sudo locale-gen en_US.UTF-8

# init a postgres data dir under `~/.local/share` and start db server
initdb --locale en_US.UTF-8 -D ~/.local/share/postgres/data
postgresql-check-db-dir ~/.local/share/postgres/data
# this creates a pg_hba.conf file in the postges folder that is set to 'trust'

# in one tab, start postgres
postgres -D ~/.local/share/postgres/data -k ~/.local/share/postgres
# in another, start redis
redis-server
# in yet another, run the rails tests
bin/rails db:create
bin/rails db:test:prepare
bundle exec rspec
#
```

All rails tests but some weird VCR failures pass. Calling it a win.

No systemd in distroboxes. Have to launch services by hand, though maybe distrobox-export can export the service in a cleaner way. Everything seems to work though. Going to take a break and think about how to simplify or speedup getting into a working dev environment.

Redis writes to the directory you run it in. Will need to maybe start it in ~/.local/share/redis in the future.

Works ok, but codec situation in this OS sucks and so much has to be installed or layered on. Backed up disk image to external SSD and moved on to Garuda here.
