# Add ~/.local/bin to PATH
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end

# initialize direnv, if installed
if which direnv &> /dev/null
  direnv hook fish | source
end
