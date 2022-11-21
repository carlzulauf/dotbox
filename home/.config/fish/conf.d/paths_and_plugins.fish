# Add ~/.local/bin to PATH
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end

# Add user bins from latest ruby path
if test -d ~/.local/share/gem/ruby/3.0.0/bin
  set --append PATH ~/.local/share/gem/ruby/3.0.0/bin
end

# initialize direnv, if installed
if type -q direnv
  direnv hook fish | source
end

if test -f /opt/asdf-vm/asdf.fish
  source /opt/asdf-vm/asdf.fish
end
