# micro's clipboard hook. micro uses a `micro-clip` on PATH ahead of its
# built-in wl-clipboard/xclip support, calling `micro-clip -o <reg>` to read
# and `micro-clip -i <reg>` (text on stdin) to write, with <reg> being
# "clipboard" or "primary".
#
# micro runs wl-paste with no timeout, including once at startup to probe the
# clipboard. When the compositor won't give wl-clipboard focus, as happens
# when the screen is locked and we're in over ssh, wl-paste waits forever and
# micro waits with it. Here every compositor call is bounded, and a copy kept
# under $XDG_RUNTIME_DIR keeps copy/paste working inside micro whenever the
# system clipboard can't be reached.
#
# Packaged with writeShellApplication (see defaults.nix), which supplies the
# shebang and `set -euo pipefail`.

mode=${1:-} reg=${2:-}
case $reg in
  clipboard) wl_args=() ;;
  primary) wl_args=(--primary) ;;
  *) echo "micro-clip: unknown register '$reg'" >&2; exit 2 ;;
esac

store=${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/micro-clip
mkdir -p "$store"
chmod 700 "$store"

# Generous enough that a heavily loaded machine doesn't trip it on a healthy
# compositor; a stuck one costs micro this long at startup and on each paste.
wl_timeout=5

# A locked session never hands out focus, so don't even try. The timeouts on
# the wl-* calls cover every other way the compositor can stall.
wayland_usable() {
  [[ -n ${WAYLAND_DISPLAY:-} ]] || return 1
  local session
  session=$(timeout "$wl_timeout" loginctl show-user "${USER:-$(id -un)}" -p Display --value 2>/dev/null) || return 0
  [[ $(timeout "$wl_timeout" loginctl show-session "$session" -p LockedHint --value 2>/dev/null) != yes ]]
}

case $mode in
  -o)
    if wayland_usable &&
       timeout -k 1 "$wl_timeout" wl-paste --no-newline "${wl_args[@]}" >"$store/$reg.sys" 2>/dev/null; then
      cat "$store/$reg.sys"
    else
      cat "$store/$reg" 2>/dev/null || true
    fi
    # Always succeed. On a failed read micro falls through to its built-in
    # wl-paste clipboard, which is the call that hangs.
    exit 0
    ;;
  -i)
    cat >"$store/$reg.tmp"
    mv "$store/$reg.tmp" "$store/$reg"
    if wayland_usable; then
      # wl-copy forks a daemon to serve the selection; keep it off our stdio.
      timeout -k 1 "$wl_timeout" wl-copy "${wl_args[@]}" <"$store/$reg" >/dev/null 2>&1 || true
    fi
    exit 0
    ;;
  *) echo "usage: micro-clip -o|-i clipboard|primary" >&2; exit 2 ;;
esac
