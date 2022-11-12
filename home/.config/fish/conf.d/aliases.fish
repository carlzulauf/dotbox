alias bex='bundle exec'
alias ber='bex rspec'
alias dc='docker-compose'
alias fix_keychron='echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode'
alias strip_colors='sed \'s/\x1B\[[0-9;]\{1,\}[A-Za-z]//g\''

# Replace ls with exa if available
if which exa &> /dev/null
  alias l='exa -a --color=always --group-directories-first --icons'   # short, everything
  alias ls='exa --color=always --group-directories-first --icons'     # preferred listing
  alias la='exa -la --color=always --group-directories-first --icons' # all files and dirs
  alias ll='exa -l --color=always --group-directories-first --icons'  # long format
  alias lt='exa -T --color=always --group-directories-first --icons'  # tree listing
  alias l.="exa -a | egrep '^\.'"                                     # show only dotfiles
else
  # ls aliases here
end
