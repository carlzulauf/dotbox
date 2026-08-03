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

  # Only claim the shared gem tree outside a devshell. `nix develop` (and
  # nix-direnv, which also exports IN_NIX_SHELL) hands us a project-specific
  # GEM_HOME with its bin already on PATH; overwriting that points gems at
  # $NIX_GEM_HOME, which is one flat directory shared by every Ruby. Gems with
  # C extensions are then invisible, because their extensions/ subdirectory is
  # named for the ABI of whichever Ruby installed them -- e.g. ruby-lsp under
  # Ruby 3.4.9 failing with "Could not find 'rbs'" while rbs sits right there,
  # built for 4.0.0. Note this file runs for `fish -c` too, not just
  # interactive shells, so it reaches editor/LSP subprocesses as well.
  #
  # GEM_HOME's non-devshell default actually comes from /etc/set-environment
  # (nixos environment.variables), which fish applies in
  # nixos-env-preinit.fish before this file. That is guarded by an exported
  # __NIXOS_SET_ENVIRONMENT_DONE, so it does not re-fire inside a devshell --
  # but a shell started from a scrubbed env (`env -i`) loses the guard and
  # gets the system GEM_HOME back regardless of the check below.
  if test -z "$IN_NIX_SHELL"
    set GEM_HOME $NIX_GEM_HOME
    set GEM_PATH $NIX_GEM_HOME
    if not contains $NIX_GEM_BIN $PATH
      set --prepend PATH $NIX_GEM_BIN
    end
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
