{ config, lib, pkgs, nixpkgs-master, ... }:

{
  environment.systemPackages = with pkgs; [
    git-lfs
    nixpkgs-master.llmfit
  ];

  # posthog (open-webui -> chromadb -> posthog) is marked broken since mcp 2.x
  #  only because one test fails; drop once NixOS/nixpkgs#578265 lands
  nixpkgs.overlays = [ (final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [ (pyfinal: pyprev: {
      posthog = pyprev.posthog.overridePythonAttrs (old: {
        doCheck = false;
        meta = old.meta // { broken = false; };
      });
    }) ];
  }) ];

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
    # nixpkgs passes `--set NAME value` as one makeWrapperArgs string, which
    #  python packages' new __structuredAttrs default no longer word-splits
    package = lib.mkDefault (pkgs.open-webui.overridePythonAttrs (old: {
      makeWrapperArgs = [
        "--set" "FRONTEND_BUILD_DIR" "${pkgs.open-webui.frontend}/share/open-webui"
      ];
    }));
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };
}
