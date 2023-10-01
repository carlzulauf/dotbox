# Add ~/.local/bin to PATH, early (prepend)
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end

# Add gem bins to PATH, late (append)
if test -d ~/.local/share/gem/ruby/3.0.0/bin
  if not contains -- ~/.local/share/gem/ruby/3.0.0/bin $PATH
    set --append PATH ~/.local/share/gem/ruby/3.0.0/bin
  end
end

# Add gem bins to PATH, late (append)
if test -d ~/.gem/ruby/3.0.0/bin
  if not contains -- ~/.gem/ruby/3.0.0/bin $PATH
    set --append PATH ~/.gem/ruby/3.0.0/bin
  end
end
