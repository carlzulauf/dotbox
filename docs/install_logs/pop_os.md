# Pop!_OS

Ubuntu/debian based distro that comes with "Cosmic" Desktop (Gnome with extensions.

## Why?

Screen rotation works out of the box on my HP Envy in Pop!_OS. Seems stable too. Comes with flatpak support by default. Uses apt for some stuff. Pop!_Shop seems to default to flathub when available.

## Restore Gnome

I don't like cosmic. I don't like having the Gnome dash disabled. I don't like the Super+Number shortcuts not working. If I'm going to stick to this OS I have to get back to default Gnome, or at least close. It's Gnome 42, not 43, but having this work like a tablet sometimes is more important.

### Step 1: Disable Extensions

Use the Extensions app to disable everything except Pop Shell (tiling support), System76 Power (quick power profile switcher... nice), AppIndicators.

### Step 2: Restore Shortcuts

The entire `org.gnome.shell.keybindings` collection is missing so using dconf-editor to do this was a bust.

Just used the commands from the Manjaro adventure.

```
gsettings set org.gnome.shell.keybindings switch-to-application-1 "['<Super>1']"
gsettings set org.gnome.shell.keybindings switch-to-application-2 "['<Super>2']"
gsettings set org.gnome.shell.keybindings switch-to-application-3 "['<Super>3']"
gsettings set org.gnome.shell.keybindings switch-to-application-4 "['<Super>4']"
gsettings set org.gnome.shell.keybindings switch-to-application-5 "['<Super>5']"
gsettings set org.gnome.shell.keybindings switch-to-application-6 "['<Super>6']"
gsettings set org.gnome.shell.keybindings switch-to-application-7 "['<Super>7']"
gsettings set org.gnome.shell.keybindings switch-to-application-8 "['<Super>8']"
gsettings set org.gnome.shell.keybindings switch-to-application-9 "['<Super>9']"
```

I also changed some shortcuts through the keyboard shortcuts GUI in Settings to make them more like Gnome defaults, or just more to my preference.

## Dev Environment Setup

A psuedo-log grouped by category.

### Shell

Using apt for some stuff like a system ruby and basic shell stuff.

```
sudo apt install ruby podman-docker fish direnv tmux exa
sudo gem install pry
curl -sS https://starship.rs/install.sh | sh
# copied projects folder with dotbox+dotbox-private repos
cd projects/dotbox
bin/install_dotfiles
```

Create an arch distrobox to have a nicely configured base.

```
distrobox create -i docker.io/library/archlinux:latest arch-shell
distrobox enter arch-shell
as:$ sudo pacman -S which neofetch sysstat smartmontools iotop bind nano ruby ruby ruby-pry ruby-docs starship exa git man-db base-devel openssh tmux
as:$ cd ~/projects/0wnloads/yay
as:$ makepkg -si
```

Then, use that to create an asdf box and db boxes.

```
distrobox stop arch-shell
distrobox create --clone arch-shell arch-asdf
distrobox enter arch-asdf
aa:$ yay -S asdf-vm
# need to re-enter distrobox for asdf to be in path
```

### GUI

Mostly flatpaks. It's already the Pop!_OS way.

```
flatpak install --assumeyes flathub com.google.Chrome org.keepassxc.KeePassXC org.pulseaudio.pavucontrol com.github.zocker_160.SyncThingy org.gimp.GIMP org.inkscape.Inkscape org.signal.Signal org.videolan.VLC com.transmissionbt.Transmission com.github.jeromerobert.pdfarranger org.gtk.Gtk3theme.Adwaita-dark com.visualstudio.code-oss com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager
```

### Getting a basic real world app to work

This one has ruby+javascript, but no DB.

Start by creating a tmux session within the distrobox and project dir.

```
tproj --distrobox=arch-asdf --dir=projects/example ex
```

Inside the distrobox, install the asdf plugins needed. Had to exit shell again for them to show up after install.

```
asdf plugin add ruby
asdf install ruby 3.1.2
asdf local ruby 3.1.2
asdf plugin add nodejs
asdf install nodejs 16.14.0
asdf local nodejs 16.14.0
asdf plugin add yarn
asdf install yarn latest
asdf local yarn latest
```

At this point I just had to grab ruby gems and npm packages and everything worked.

```
bundle install
yarn install
```
