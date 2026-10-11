{ config, lib, pkgs, nixpkgs-master, ... }:

{
  environment.systemPackages = with pkgs; [
    git-lfs
    nixpkgs-master.llmfit
  ];

  # Both listen on every interface but leave the firewall closed, so they're
  # reachable over the tailnet (a trusted interface, see defaults.nix) and not
  # from the LAN. ollama has no authentication, and open-webui has none on the
  # hosts that turn WEBUI_AUTH off.
  services.ollama = {
    enable = lib.mkDefault true;
    host = lib.mkDefault "0.0.0.0";
    package = lib.mkDefault nixpkgs-master.ollama-vulkan;
  };

  services.open-webui = {
    enable = true;
    host = lib.mkDefault "0.0.0.0";
    port = 4141; # AI! AI!
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };
}
