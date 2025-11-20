alias bex='bundle exec'
alias ber='bex rspec'
alias fix_keychron='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias strip_colors='sed \'s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g\''

alias dc='docker-compose'
alias dcr='docker-compose run --rm -it'

alias lsfs="dysk -a -f 'type=btrfs|type=ext4|type=merger|type=vfat|type=f2fs|type=ntfs'"
alias fsls=lsfs

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
