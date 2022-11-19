## Garuda Linux

Yeah, all that fedora silverblue stuff is well and good and works pretty well, but silverblue has some issues. Like the rest of fedora they've decided to cower to their own theoretical arguments when it comes to the legality of including hardware decoding for h265 on AMD hardware. I sometimes think IBM/RedHat just likes to kneecap Fedora a bit. I'm not going to build a custom kernel or deal with shitty battery life watching youtube.

Going back to Garuda. This time I'm going to treat it like an immutable OS and try to lean heavy on flatpaks.

Copied this project into `~/projects` again.

```
sudo pacman -S flatpak ruby ruby-pry
cd projects/dotbox
bin/install
```
The AUR is enabled by default. That gives me pause for this being a super stable system. Maybe manjaro.

Backing up garuda

```
sudo dd status=progress bs=16M if=/dev/nvme0n1 | lbzip2 > lenovo_garuda_full_disk.img.lbzip2
```
