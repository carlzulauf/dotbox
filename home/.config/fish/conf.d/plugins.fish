## Starship prompt if we're interactive and starship in PATH
if status --is-interactive && type -q starship
  source (starship init fish --print-full-init | psub)
end

## Advanced command-not-found hook, if found
# if test -f /usr/share/doc/find-the-command/ftc.fish
#   source /usr/share/doc/find-the-command/ftc.fish
# end

# initialize direnv, if installed
if type -q direnv
  direnv hook fish | source
end

# if asdf is in the usual place, load it
if test -f /opt/asdf-vm/asdf.fish
  source /opt/asdf-vm/asdf.fish
end
