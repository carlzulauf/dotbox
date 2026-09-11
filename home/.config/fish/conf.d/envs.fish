# The gcr/gnome-keyring ssh-agent holds the deploy + GitHub keys, but shells
# started outside the desktop session (distrobox) don't inherit the socket.
# Capistrano needs it for forward_agent (remote git fetch from GitHub).
if test -z "$SSH_AUTH_SOCK"; and test -S /run/user/(id -u)/gcr/ssh
  set --global --export SSH_AUTH_SOCK /run/user/(id -u)/gcr/ssh
end

if test -d ~/.local/ds4/gguf
  set --global --export DS4_GGUF_DIR "$HOME/.local/ds4/gguf"
  alias ds4-start="ds4 -m $DS4_GGUF_DIR/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf"
end

# wl-copy needs WAYLAND_DISPLAY, and tmux drops it from a session whenever a
# client without it attaches, which silently breaks copying in micro (and every
# other wl-clipboard consumer) in that session's panes. Recover it from the tmux
# server, then fall back to probing for the compositor socket directly.
if test -z "$WAYLAND_DISPLAY"
  if set -q TMUX
    tmux_refresh_env
  end

  if test -z "$WAYLAND_DISPLAY"; and test -n "$XDG_RUNTIME_DIR"
    for wl_sock in $XDG_RUNTIME_DIR/wayland-*
      if test -S $wl_sock
        set --global --export WAYLAND_DISPLAY (string replace "$XDG_RUNTIME_DIR/" '' $wl_sock)
        break
      end
    end
    set --erase wl_sock
  end
end
