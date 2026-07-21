{ pkgs, ... }:
{
  home.stateVersion = "24.11";
  home.username = "carl";
  home.homeDirectory = "/home/carl";

  programs.tmux = {
    enable = true;
  };
}
