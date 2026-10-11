# Steam, for gaming machines (via gaming.nix) and for ones that only stream.
# gamescopeSession also turns programs.gamescope on.
{ ... }:

{
  hardware.steam-hardware.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
}
