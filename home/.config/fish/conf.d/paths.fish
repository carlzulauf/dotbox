# if shims are present and asdf is loaded, make sure shims are early in PATH
if test -d ~/.asdf/shims; and type -q asdf
  if not contains -- ~/.asdf/shims $PATH
    set --prepend PATH ~/.asdf/shims
  end
end

# Add ~/.local/bin to PATH early, even before asdf
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end

# Add gem bins to PATH, late (append)
# if test -d ~/.gem/ruby/3.0.0/bin
#   if not contains -- ~/.gem/ruby/3.0.0/bin $PATH
#     set --append PATH ~/.gem/ruby/3.0.0/bin
#   end
# end
