{ config, pkgs, llm-agents, ... }:

{
  environment.systemPackages = [
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
    (pkgs.callPackage ../pkgs/t3code-desktop { })
  ];
}
