## Manjaro

Flatpaks easy to switch on through Pamac preferences.

OMG. None of the default gnome shortcuts work. Why would I want Super+Number to switch to a bunch of different workspaces? I maybe use 1/2, 3 at most and I know the left/right shortcut. Luckily that works. Super+Up also doesn't work.

The folks over at Manjaro seem to operate a most unhelpful forum. A couple questions opened about getting these back and both closed without anything approaching a solution to the Super shortcuts.

This is what was supposed to fix it:

```
sudo pacman -R manjaro-gnome-extension-settings
```

I'm so far down this rabbit hole now and I'm determined to understand what's going on and notate it because this has happened before and I'm sick of having no solution to deep gnome config issues like this.

I think we have to look around here: `/usr/share/glib-2.0/schemas`

Going to remove a couple extensions fully:

```
sudo pacman -R gnome-shell-extension-dash-to-dock gnome-shell-extension-dash-to-panel
```

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

I guess we can add back the stuff we removed since it didn't make a difference. Getting back to stock Manjaro with those gsettings applied. Also, ruby.

```
sudo pacman -S manjaro-gnome-extension-settings gnome-shell-extension-dash-to-dock gnome-shell-extension-dash-to-panel
```

We can install the dot files now and some essentials.

```
sudo pacman -S fish exa starship tmux direnv neofetch bind sysstat ruby-webrick ruby-docs ttf-ubuntumono-nerd
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

Looks like I'm going to need some container infrastructure. Going with podman as I think non-priveleged containers are easier there. I don't want to deal with user groups.

```
sudo pacman -S podman podman-docker podman-compose
```
