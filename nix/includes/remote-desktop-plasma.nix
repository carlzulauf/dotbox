# Remote desktop between my machines over the tailnet, using RDP. This is the
# Plasma side; GNOME machines get remote-desktop-gnome.nix from gnome.nix.
#
# Port 3389 (the standard RDP port) shares the desktop that is already
# running on the physical display, exactly as it was left. krdp only listens
# while that user is logged in, so an open 3389 means "there is a session to
# share". A machine sitting at SDDM can't be reached this way.
#
# Clients connect with GNOME Connections, with each host added by hand.
#
# krdp checks the real account password through PAM, so unlike GNOME there is
# no separate RDP password file to set up.
{ config, lib, pkgs, ... }:
let
  port = 3389;
in
{
  # KConfig falls back to /etc/xdg for keys missing from ~/.config/krdpserverrc.
  # SystemUserEnabled checks the account password via PAM ("login").
  environment.etc."xdg/krdpserverrc".text = lib.generators.toINI { } {
    General = {
      ListenPort = port;
      SystemUserEnabled = true;
      Autostart = true;
    };
  };

  # Same name as krdp's own unit, so the KCM's autostart toggle can't start
  # a second copy. --plasma uses KWin's privileged screencast/fake-input
  # protocols instead of the portal, whose "allow remote control" prompt
  # would need someone at the machine. KWin grants those to the binary
  # named in org.kde.krdpserver.desktop, so the path must stay the
  # package's own krdpserver.
  systemd.user.services."app-org.kde.krdpserver" = {
    description = "KRDP Server";
    after = [ "plasma-xdg-desktop-portal-kde.service" "plasma-core.target" ];
    wantedBy = [ "plasma-workspace.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.kdePackages.krdp}/bin/krdpserver --plasma --port ${toString port}";
      Restart = "on-abnormal";
    };
  };
}
