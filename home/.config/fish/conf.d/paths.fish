if is_local_or_asdf_container
  if type -q asdf
    # if shims are present and asdf is loaded, make sure shims are early in PATH
    if test -d ~/.asdf/shims
      if not contains -- ~/.asdf/shims $PATH
        set --prepend PATH ~/.asdf/shims
      end
    end
  else
    strip_path "/.asdf/"
  end

  if type -q nix-store
    set --global --export NIX_GEM_HOME "$HOME/.local/share/gems/nix"
    set --global --export NIX_GEM_BIN "$NIX_GEM_HOME/bin"

    if test -n "$CONTAINER_GEM_BIN"
      strip_path "$CONTAINER_GEM_BIN"
    end

    set GEM_HOME $NIX_GEM_HOME
    if not contains $NIX_GEM_BIN $PATH
      set --append PATH $NIX_GEM_BIN
    end
  else
    if test -n "$NIX_GEM_BIN"
      strip_path "$NIX_GEM_BIN"
    end
  end

else
  strip_path "/.asdf/"
  if test -n "$NIX_GEM_BIN"
    strip_path "$NIX_GEM_BIN"
  end

  if test -n "$CONTAINER_ID"
    set --global --export CONTAINER_GEM_HOME "$HOME/.local/share/gems/$CONTAINER_ID"
    set --global --export CONTAINER_GEM_BIN "$CONTAINER_GEM_HOME/bin"

    set GEM_HOME $CONTAINER_GEM_HOME
    if not contains $CONTAINER_GEM_BIN $PATH
      set --append PATH $CONTAINER_GEM_BIN
    end
  end
end

# Add ~/.local/bin to PATH early, even before asdf
if test -d ~/.local/bin
  if not contains -- ~/.local/bin $PATH
    set --prepend PATH ~/.local/bin
  end
end
