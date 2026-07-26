# Invoked by the ruby-lsp VSCodium extension as `ruby_lsp_activate && ruby ...`,
# run by `fish -c` with the workspace folder as cwd. Its job is to put this
# shell into the project's Ruby environment.
#
# The extension's `rubyLsp.customRubyCommand` setting is machine-scoped, so it
# is a single global value; this function is where per-project differences go.
# Opt a project in with `"rubyLsp.rubyVersionManager": {"identifier": "custom"}`
# in that project's .vscode/settings.json.
#
# Must exit 0, otherwise the `&&` short-circuits and ruby is never run.
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
