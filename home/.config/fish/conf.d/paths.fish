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

if type -q asdf
  # clear out everything and let adsf figure it out
  if test -n "$NIX_GEM_BIN"; and set -l index (contains -i $NIX_GEM_BIN $PATH)
    set -e PATH[$index]
  end

  if test -n "$CONTAINER_GEM_BIN"; and set -l index (contains -i $CONTAINER_GEM_BIN $PATH)
    set -e PATH[$index]
  end

  set -e GEM_HOME
else if test -n "$CONTAINER_ID"
  set --global --export CONTAINER_GEM_HOME "$HOME/.local/share/gems/$CONTAINER_ID"
  set --global --export CONTAINER_GEM_BIN "$CONTAINER_GEM_HOME/bin"

  if test -n "$NIX_GEM_BIN"; and set -l index (contains -i $NIX_GEM_BIN $PATH)
    set -e PATH[$index]
  end

  set GEM_HOME $CONTAINER_GEM_HOME
  set --append PATH $CONTAINER_GEM_BIN
else if type -q nix-store
  set --global --export NIX_GEM_HOME "$HOME/.local/share/gems/nix"
  set --global --export NIX_GEM_BIN "$NIX_GEM_HOME/bin"

  if test -n "$CONTAINER_GEM_BIN"; and set -l index (contains -i $CONTAINER_GEM_BIN $PATH)
    set -e PATH[$index]
  end

  set GEM_HOME $NIX_GEM_HOME
  set --append PATH $NIX_GEM_BIN
end
