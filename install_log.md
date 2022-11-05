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

