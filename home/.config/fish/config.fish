## Starship prompt if we're interactive and starship in PATH
if status --is-interactive && type -q starship
  source (starship init fish --print-full-init | psub)
end

## Advanced command-not-found hook, if found
# if test -f /usr/share/doc/find-the-command/ftc.fish
#   source /usr/share/doc/find-the-command/ftc.fish
# end
