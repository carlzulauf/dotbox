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
