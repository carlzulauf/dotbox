# Re-import the desktop session variables from the tmux server.
#
# tmux's update-environment rewrites a session's environment every time a
# client attaches. When a client that has no WAYLAND_DISPLAY attaches (ssh, a
# plain console), tmux records the variable as *removed* for that session
# ("-WAYLAND_DISPLAY" in show-environment), and every pane opened afterwards
# has no compositor to talk to. wl-copy then fails silently, so micro reports
# "Copied selection" while the Wayland clipboard is never touched.
#
# The server-global environment keeps the original values, so pull from there
# first and let the session override whatever it still defines.

function tmux_refresh_env --description 'Re-import desktop session vars from the tmux server environment'
  if not set -q TMUX
    echo "tmux_refresh_env: not inside tmux" >&2
    return 1
  end

  set -l wanted DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR XDG_SESSION_TYPE SSH_AUTH_SOCK

  for line in (tmux show-environment -g 2>/dev/null) (tmux show-environment 2>/dev/null)
    set -l pair (string split -m1 = -- $line)
    # Removed variables come back as "-NAME" and split into a single field.
    test (count $pair) -eq 2; or continue
    contains -- $pair[1] $wanted; or continue
    set --global --export $pair[1] $pair[2]
  end

  return 0
end
