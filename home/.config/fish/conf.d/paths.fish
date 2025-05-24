# Add ~/.asdf/shims to PATH early (prepend), but only in containers
if test ~/.asdf/shims; and test -n "$CONTAINER_ID"
  if not contains -- ~/.asdf/shims $PATH
    set --prepend PATH ~/.asdf/shims
  end
end

# Add ~/.local/bin to PATH early (prepend) before asdf
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
