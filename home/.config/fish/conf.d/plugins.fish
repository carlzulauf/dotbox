## Starship prompt if we're interactive and starship in PATH

# If we're interactive, configure the prompt
if status --is-interactive

  # use starship prompt if it's available
  if type -q starship
    source (starship init fish --print-full-init | psub)

  else # otherwise, look in fish_prompt.fish which uses terlar prompt by default

    if test -f ~/.config/fish/fish_prompt.fish; and type -q prompt_login
      source ~/.config/fish/fish_prompt.fish
    end

  end
end

## Advanced command-not-found hook, if found
# if test -f /usr/share/doc/find-the-command/ftc.fish
#   source /usr/share/doc/find-the-command/ftc.fish
# end

# initialize direnv, if installed
if type -q direnv
  direnv hook fish | source
end

# maybe asdf is installed for the current user
if test -f ~/.asdf/asdf.fish
  source ~/.asdf/asdf.fish
else
  # otherwise, if asdf is installed globally in the usual place, load it
  if test -f /opt/asdf-vm/asdf.fish
    source /opt/asdf-vm/asdf.fish
  end
end
