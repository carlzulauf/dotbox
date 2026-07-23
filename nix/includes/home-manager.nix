{ pkgs, lib, guiEnabled, ... }:

{
  home.stateVersion = "24.11";
  home.username = "carl";
  home.homeDirectory = "/home/carl";

  programs.tmux = {
    enable = true;
  };

  # Only enable GUI apps (like vscodium) on machines that opt in (e.g., those with gui.nix)
  programs.vscodium = lib.mkIf guiEnabled {
    enable = true;
    # Allow runtime installation of extensions, and give extensions like ruby-lsp a reasonable build environment
    package = pkgs.vscodium.fhsWithPackages (p: with p; [
      gcc gnumake
      libyaml
    ]);
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        continue.continue
        jnoortheen.nix-ide
        # anthropic.claude-code
        shopify.ruby-lsp
        # BriteSnow.vscode-toggle-quotes # not supported for some reason
      ];
    };
  };
}
