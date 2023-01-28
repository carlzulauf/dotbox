alias bex='bundle exec'
alias ber='bex rspec'
alias dc='docker-compose'
alias fix_keychron='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias strip_colors='sed \'s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g\''

# Replace ls with exa if available
if type -q exa
  alias l='exa -a --color=always --group-directories-first --icons'   # short, everything
  alias ls='exa --color=always --group-directories-first --icons'     # preferred listing
  alias la='exa -la --color=always --group-directories-first --icons' # all files and dirs
  alias ll='exa -l --color=always --group-directories-first --icons'  # long format
  alias lt='exa -T --color=always --group-directories-first --icons'  # tree listing
  alias l.="exa -a | egrep '^\.'"                                     # show only dotfiles
else
  # ls aliases here
end

if test -e /run/.containerenv; or test -e /.dockerenv
  # we're inside of a container/distrobox
  if test -d ~/.var/app/com.visualstudio.code-oss/data/; or test -d ~/.var/app/com.visualstudio.code/data/
    if test -d ~/.var/app/com.visualstudio.code-oss/data/
      alias code='distrobox-host-exec flatpak run com.visualstudio.code-oss'
      alias codo='distrobox-host-exec flatpak run com.visualstudio.code-oss'
    end

    if test -d ~/.var/app/com.visualstudio.code/data/
      alias code='distrobox-host-exec flatpak run com.visualstudio.code'
      alias vscode='distrobox-host-exec flatpak run com.visualstudio.code'
      alias vsc='distrobox-host-exec flatpak run com.visualstudio.code'
    end
  else
    alias code='distrobox-host-exec code'
    alias codo='distrobox-host-exec code'
  end
else
  # we're not inside of a container (on host OS)
  if test -d ~/.var/app/com.visualstudio.code-oss/data/; or test -d ~/.var/app/com.visualstudio.code/data/
    if test -d ~/.var/app/com.visualstudio.code-oss/data/
      alias code='flatpak run com.visualstudio.code-oss'
      alias codo='flatpak run com.visualstudio.code-oss'
    end

    if test -d ~/.var/app/com.visualstudio.code/data/
      alias code='flatpak run com.visualstudio.code'
      alias vscode='flatpak run com.visualstudio.code'
      alias vsc='flatpak run com.visualstudio.code'
    end
  else
    # assume we have natively installed code/vscode
    # no need for additional aliases in this case
  end
end
