{ config, lib, pkgs, nixpkgs-master, llm-agents, ... }:
let
  # moreStablePkgs = import (builtins.fetchTarball{
  #   url = "https://github.com/NixOS/nixpkgs/archive/c7cc0ac6c16499d3937dd5eb7446ab1cc1df304f.tar.gz";
  #   sha256 = "sha256:0qgz2rkfrxqbd65fcp7pv2zcvdfbh759d0wqmn3cr0rzrlfznb49";
  # }) {
  #   system = "x86_64-linux";
  #   config.allowUnfree = true;
  # };
in
{
  environment.systemPackages = with pkgs; [
    git-lfs
    intel-gpu-tools

    nixpkgs-master.llmfit
    # nixpkgs-master.claude-code
    # nixpkgs-master.pi-coding-agent
    # nixpkgs-master.opencode
    llm-agents.claude-code
    llm-agents.pi
    llm-agents.opencode
    llm-agents.agent-browser
  ];

  services.ollama = {
    enable = lib.mkDefault true;
    host = lib.mkDefault "0.0.0.0";
    openFirewall = true;
    package = lib.mkDefault nixpkgs-master.ollama;
  };

  services.open-webui = {
    enable = true;
    host = lib.mkDefault "0.0.0.0";
    port = 4141; # AI! AI!
    openFirewall = true;
    # package = lib.mkDefault nixpkgs-master.open-webui;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      # WEBUI_AUTH = "False";
    };
  };
}
