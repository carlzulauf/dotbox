if test -d ~/.local/ds4/gguf
  set --global --export DS4_GGUF_DIR "$HOME/.local/ds4/gguf"
  alias ds4-start="ds4 -m $DS4_GGUF_DIR/DeepSeek-V4-Flash-IQ2XXS-w2Q2K-AProjQ8-SExpQ8-OutQ8-chat-v2-imatrix.gguf"
end
