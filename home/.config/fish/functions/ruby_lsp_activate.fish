# Invoked for the ruby-lsp extension by ~/.local/bin/ruby_lsp_env, a fish
# script run with the workspace folder as cwd, which prints the environment
# this leaves for the extension's shell (fish or /bin/sh) to eval, as
# `eval "$(~/.local/bin/ruby_lsp_env)" && ruby ...`. Its job is to put this
# shell into the project's Ruby environment. Anything it prints goes to
# stderr, so it isn't eval'd.
#
# The extension's `rubyLsp.customRubyCommand` setting is machine-scoped, so it
# is a single global value; this function is where per-project differences go.
# Opt a project in with `"rubyLsp.rubyVersionManager": {"identifier": "custom"}`
# in that project's .vscode/settings.json.
function ruby_lsp_activate --description 'Per-project Ruby environment activation for ruby-lsp'
    # 1. A project can take full control by committing .ruby-lsp-env.fish.
    if test -f .ruby-lsp-env.fish
        source .ruby-lsp-env.fish
        return 0
    end

    # 2. Otherwise, load direnv if the project uses it (nix flakes, etc).
    if test -f .envrc; and command --query direnv
        direnv export fish | source
    end

    return 0
end
