# Manjaro

Flatpaks easy to switch on through Pamac preferences.

OMG. None of the default gnome shortcuts work. Why would I want Super+Number to switch to a bunch of different workspaces? I maybe use 1/2, 3 at most and I know the left/right shortcut. Luckily that works. Super+Up also doesn't work.

The folks over at Manjaro seem to operate a most unhelpful forum. A couple questions opened about getting these back and both closed without anything approaching a solution to the Super shortcuts.

Removing `manjaro-gnome-extension-settings` was supposed to fix it. It did not.

I'm so far down this rabbit hole now and I'm determined to understand what's going on and notate it because this has happened before and I'm sick of having no solution to deep gnome config issues like this.

I think we have to look around here: `/usr/share/glib-2.0/schemas`

Ok, so, it looks like `gnome-shell` has global (xml) settings with the correct keybindings but for some reason the gsettings database says different. No amount of removing packages will solve that. The settings for `switch-to-application` are cleared out:

```
$ gsettings list-recursively org.gnome.shell.keybindings
org.gnome.shell.keybindings focus-active-notification ['<Super>n']
org.gnome.shell.keybindings open-application-menu ['<Super>F10']
org.gnome.shell.keybindings screenshot ['<Shift>Print']
org.gnome.shell.keybindings screenshot-window ['<Alt>Print']
org.gnome.shell.keybindings shift-overview-down ['<Super><Alt>Down']
org.gnome.shell.keybindings shift-overview-up ['<Super><Alt>Up']
org.gnome.shell.keybindings show-screen-recording-ui ['<Ctrl><Shift><Alt>R']
org.gnome.shell.keybindings show-screenshot-ui ['Print']
org.gnome.shell.keybindings switch-to-application-1 @as []
org.gnome.shell.keybindings switch-to-application-2 @as []
org.gnome.shell.keybindings switch-to-application-3 @as []
org.gnome.shell.keybindings switch-to-application-4 @as []
org.gnome.shell.keybindings switch-to-application-5 @as []
org.gnome.shell.keybindings switch-to-application-6 @as []
org.gnome.shell.keybindings switch-to-application-7 @as []
org.gnome.shell.keybindings switch-to-application-8 @as []
org.gnome.shell.keybindings switch-to-application-9 @as []
org.gnome.shell.keybindings toggle-application-view ['<Super>a']
org.gnome.shell.keybindings toggle-message-tray ['<Super>v', '<Super>m']
org.gnome.shell.keybindings toggle-overview ['<Super>s']
```

Used some ruby to set them up.

```
pry> (1..9).map{|n| cmd = %{gsettings set org.gnome.shell.keybindings switch-to-application-#{n} "['<Super>#{n}']"}; puts "$ #{cmd}"; system cmd }
$ gsettings set org.gnome.shell.keybindings switch-to-application-1 "['<Super>1']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-2 "['<Super>2']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-3 "['<Super>3']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-4 "['<Super>4']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-5 "['<Super>5']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-6 "['<Super>6']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-7 "['<Super>7']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-8 "['<Super>8']"
$ gsettings set org.gnome.shell.keybindings switch-to-application-9 "['<Super>9']"
=> [true, true, true, true, true, true, true, true, true]
```

Foudn some more conflicting keybindings here, which I cleared out:

```
gsettings list-recursively org.gnome.desktop.wm.keybindings
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "[]"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "[]"
...
```

I guess we can add back the stuff we removed since it didn't make a difference. Getting back to stock Manjaro with those gsettings applied.

We can install the dot files now and some essentials.

```
sudo pacman -S fish exa starship tmux direnv neofetch bind sysstat ruby ruby-pry ruby-webrick ruby-docs ttf-ubuntumono-nerd
```

Then used `chsh` to change to fish.

Now some flatpaks. Just the ones we had in fedora for now.

```
flatpak install --assumeyes flathub com.google.Chrome org.keepassxc.KeePassXC org.pulseaudio.pavucontrol com.github.zocker_160.SyncThingy org.gimp.GIMP org.inkscape.Inkscape org.signal.Signal org.videolan.VLC com.transmissionbt.Transmission com.github.jeromerobert.pdfarranger org.gtk.Gtk3theme.Adwaita-dark com.visualstudio.code-oss com.github.tchx84.Flatseal com.mattjakeman.ExtensionManager
```

Frustrations and theme weirdness aside, Manjaro comes with a ton of stuff out of the box which I love and should make it easier to leave the base OS alone.

Going to start installing distrobox and get ssms working fully via asdf.

```
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix ~/.local
```

Looks like I'm going to need some container infrastructure. Going with podman as I think non-priveleged containers are easier there. I don't want to deal with user groups. Also, we're rocking an old LTS kernel (5.15). Moving up to 6.0.

```
sudo pacman -S podman podman-docker podman-compose linux60 linux60-headers
```

Still can't create containers. Complains about `carl` not having `subuid` ranges in `/etc/subuid`. Guess we have to check the docs for "rootless mode".

```
sudo usermod --add-subuids 100000-199999 --add-subgids 100000-199999 carl
podman system migrate
distrobox create -i archlinux arch-shell
distrobox enter arch-shell
as:$ sudo pacman -S which neofetch sysstat smartmontools iotop bind nano ruby ruby ruby-pry ruby-docs starship git man-db
```

Everything is working. Not sure where services should live. Maybe I should take the most space efficient approach? Starting with redis, here are some options I see:

* Just start the official redis container from dockerhub via a single docker command.
* Use `Dockerfile`/`docker-compose.yml` and launch service the old fashion way.
* Make a distrobox from one of the following starting points:
  * existing arch-shell image
  * official redis image
  * alpine
  * arch

Found example of using custom Dockerfile [here](https://github.com/89luca89/distrobox/blob/main/docs/distrobox_gentoo.md).

## How do we measure the disk space of images?

We can get some idea from `podman images --all`, but not sure if there are lots of volumes I might not be seeing. `podman volume ls` lists the volumes, but doesn't say where they are or how big.

## Could cloning from an existing distrobox be the most space efficient?

Maybe, but starting from the official container seems more straightforward.

## Dokku

Moved work on a local dokku to another doc.

## More Installs

Installing some more flatpaks:

```
flatpak install flathub com.visualstudio.code
```

My dockerfiles won't build. Turns out podman is configured to require fully qualified container names including the registry. Docker.io should be a given, so adding a file with these contents to `/etc/containers/registries.conf.d/search-registries.conf`. Found an example [here](https://github.com/containers/podman/blob/main/test/registries.conf)

```
unqualified-search-registries = ['docker.io', 'quay.io']
```

## asdf via distrobox

Trying to get a real fully working example of using asdf via distrobox to run my rails app, ssms. Not just tests, but the full thing with containers for postgres and redis.

```
distrobox create --clone arch-shell arch-asdf
distrobox enter arch-asdf
aa:$ sudo pacman -Syu base-devel
aa:$ cd ~/projects/0wnloads/yay
aa:$ makepkg -si
aa:$ yay -S asdf-vm
aa:$ exit
# need to re-enter distrobox for asdf to be in path
```

Now, inside the `arch-asdf` distrobox and within the ssms project directory, we install the versions we need.

```
asdf plugin add ruby
asdf plugin add nodejs
asdf plugin add yarn
asdf install ruby 3.1.2
asdf install nodejs 14.21.1
asdf install yarn latest
asdf local ruby 3.1.2
asdf local nodejs 14.21.1
asdf local yarn latest
```

Now we install the ruby and javascript requirements for the app.

```
yarn install
bundle install
```

## Additional Storage

Added a 2TB SSD to the laptop and formatted it as btrfs using gparted. I want to have a subvolume mounted in my home directory as `files`. There is no way to containerize this process.

Mount point for root filesystem will be `/mnt/swamp`. UUID of btrfs partition is `3eb0140d-1038-4232-96c7-46b0ad63ebbf`.

First, make the mount point: `$ sudo mkdir /mnt/swamp`

Added the following to `/etc/fstab`:

```
# swamp
UUID=3eb0140d-1038-4232-96c7-46b0ad63ebbf /mnt/swamp     btrfs   subvol=/,defaults,discard=async,ssd 0 0
```

Then refreshed config and mounted the root filesystem. Added a subvolume and created mount point for it.

```
sudo systemctl daemon-reload
sudo mount /mnt/swamp
sudo btrfs subvolume create /mnt/swamp/@files
sudo mkdir /mnt/files
```

Add another line to `/etc/fstab`:

```
UUID=3eb0140d-1038-4232-96c7-46b0ad63ebbf /mnt/files     btrfs   subvol=/@files,defaults,discard=async,ssd 0 0
```

Reload config again, mount subvolume, create user owned folder within, and link into home directory:

```
sudo systemctl daemon-reload
sudo mount /mnt/files
sudo mkdir /mnt/files/carl
sudo chown carl:carl /mnt/files/carl
ln -s /mnt/files/carl ~/files
```
