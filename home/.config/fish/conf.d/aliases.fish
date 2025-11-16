alias bex='bundle exec'
alias ber='bex rspec'
alias fix_keychron='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias strip_colors='sed \'s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g\''

alias dc='docker-compose'
alias dcr='docker-compose run --rm -it'

# show all btrfs and ext4 mount points, plus any merged filesystems, and boot
alias fsls="dysk -a -f 'type=btrfs|type=ext4|type=merger|type=vfat|type=f2fs|type=ntfs'"

# Replace ls with eza if available
if type -q eza
  alias l='eza -a --color=always --group-directories-first --icons=auto'   # short, everything
  alias ls='eza --color=always --group-directories-first --icons=auto'     # preferred listing
  alias la='eza -la --color=always --group-directories-first --icons=auto' # all files and dirs
  alias ll='eza -l --color=always --group-directories-first --icons=auto'  # long format
  alias lt='eza -T --color=always --group-directories-first --icons=auto'  # tree listing
  alias l.="eza -a | egrep '^\.'"                                     # show only dotfiles
else
  # ls aliases here
end

if type -q distrobox
  alias de="distrobox enter"
  alias dbx=distrobox
end

if type -q pulsar
  alias puls=pulsar
end

if type -q paru; and not type -q yay
  alias yay="paru --bottomup"
end

# if test -e /run/.containerenv; or test -e /.dockerenv
#   # we're inside of a container/distrobox
#   alias dc='distrobox-host-exec podman-compose'
#   if test -d ~/.var/app/com.visualstudio.code-oss/data/; or test -d ~/.var/app/com.visualstudio.code/data/
#     if test -d ~/.var/app/com.visualstudio.code-oss/data/
#       alias code='distrobox-host-exec flatpak run com.visualstudio.code-oss'
#       alias codo='distrobox-host-exec flatpak run com.visualstudio.code-oss'
#     end
#
#     if test -d ~/.var/app/com.visualstudio.code/data/
#       alias code='distrobox-host-exec flatpak run com.visualstudio.code'
#       alias vscode='distrobox-host-exec flatpak run com.visualstudio.code'
#       alias vsc='distrobox-host-exec flatpak run com.visualstudio.code'
#     end
#   else
#     alias code='distrobox-host-exec code'
#     alias codo='distrobox-host-exec code'
#   end
#   if test -d ~/.var/app/dev.pulsar_edit.Pulsar
#     alias puls='distrobox-host-exec flatpak run dev.pulsar_edit.Pulsar'
#   end
# else
#   # we're not inside of a container (on host OS)
#   if test -d ~/.var/app/com.visualstudio.code-oss/data/; or test -d ~/.var/app/com.visualstudio.code/data/
#     if test -d ~/.var/app/com.visualstudio.code-oss/data/
#       alias code='flatpak run com.visualstudio.code-oss'
#       alias codo='flatpak run com.visualstudio.code-oss'
#     end
#
#     if test -d ~/.var/app/com.visualstudio.code/data/
#       alias code='flatpak run com.visualstudio.code'
#       alias vscode='flatpak run com.visualstudio.code'
#       alias vsc='flatpak run com.visualstudio.code'
#     end
#   else
#     # assume we have natively installed code/vscode
#     # no need for additional aliases in this case
#   end
#
#   if type -q pulsar
#     alias puls=pulsar
#   end
#
#   if test -d ~/.var/app/dev.pulsar_edit.Pulsar
#     alias puls='flatpak run dev.pulsar_edit.Pulsar'
#   end
# end
