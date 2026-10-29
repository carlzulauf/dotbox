{ config, pkgs, llm-agents, ... }:

{
  environment.systemPackages = [
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];
}
