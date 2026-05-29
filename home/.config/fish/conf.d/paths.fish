function remove_nix_paths
  if test -n "$NIX_GEM_BIN"
    strip_path "$NIX_GEM_BIN"
  end
  strip_path "/nix/store/"
  strip_path "nix*profile"
end

function remove_container_paths
  if test -n "$CONTAINER_GEM_BIN"
    strip_path "$CONTAINER_GEM_BIN"
    strip_path "/.asdf/"
  end
end

if is_container
  remove_nix_paths

  set --global --export CONTAINER_GEM_HOME "$HOME/.local/share/gems/$CONTAINER_ID"
  set --global --export CONTAINER_GEM_BIN "$CONTAINER_GEM_HOME/bin"
  set GEM_HOME $CONTAINER_GEM_HOME
  set GEM_PATH $CONTAINER_GEM_HOME
  if not contains $CONTAINER_GEM_BIN $PATH
    set --prepend PATH $CONTAINER_GEM_BIN
  end

  if type -q asdf
    if test -d ~/.asdf/shims
      if not contains -- ~/.asdf/shims $PATH
        set --prepend PATH ~/.asdf/shims
      end
    end
  else
    strip_path "/.asdf/"
  end
else if type -q nix-store
  remove_container_paths

  set --global --export NIX_GEM_HOME "$HOME/.local/share/gems/nix"
  set --global --export NIX_GEM_BIN "$NIX_GEM_HOME/bin"
  set GEM_HOME $NIX_GEM_HOME
  set GEM_PATH $NIX_GEM_HOME
  if not contains $NIX_GEM_BIN $PATH
    set --prepend PATH $NIX_GEM_BIN
  end
else
  remove_container_paths
  remove_nix_paths
end

# Add ~/.local/bin to PATH early, even before asdf
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end
