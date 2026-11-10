# Remote desktop between my machines over the tailnet, using RDP. This is the
# GNOME side, imported by gnome.nix; khoa's Plasma gets
# remote-desktop-plasma.nix instead.
#
# Port 3389 (the standard RDP port) shares the desktop that is already
# running on the physical display, exactly as it was left. It only listens
# while that user is logged in, so an open 3389 means "there is a session to
# share". Nothing else is served: no Remote Login, so a machine sitting at
# the GDM greeter can't be reached, and RDP never starts a new session.
#
# Clients connect with GNOME Connections, with each host added by hand.
#
# One-time setup per machine: put the RDP password (the secret for the RDP
# connection itself, not an account password) in
# ~/.config/remote-desktop/rdp-password. Without it the daemon doesn't run.
#
# Sharing a live session needs that session unlocked: mutter closes and
# refuses screen-share sessions while the lock screen is up ("Session
# creation inhibited"), so an idle machine stops answering - which is
# exactly when it's usually being connected to. The Allow Locked Remote
# Desktop extension installed below lifts that restriction (it runs in the
# "unlock-dialog" session mode); connecting to a locked host then shows its
# lock screen, which still wants the account password. It has to be enabled
# by hand once per machine, and gnome-shell skips it as OUT OF DATE whenever
# its metadata doesn't list the running shell version. Until it runs, a
# locked host can be opened up with:
#
#   ssh -t <host> sudo loginctl unlock-session <id>   # id from loginctl
#
# VNC is not used: it is slower, and gnome-remote-desktop only offers
# password auth for it. SPICE is a QEMU guest protocol with no server for a
# physical desktop.
{ config, lib, pkgs, ... }:
let
  port = 3389;
in
{
  # Provides the per-user daemon below. It also brings the system daemon,
  # which serves Remote Login by handing connections to a headless GDM
  # greeter. Masked, so it can't be started (GDM asks for it over D-Bus)
  # or hold 3389, and switching to this config stops a running one.
  services.gnome.gnome-remote-desktop.enable = true;
  systemd.services.gnome-remote-desktop.enable = false;

  # Installed, but left switched off: enable it by hand once per machine,
  # like the other extensions. Nothing here can do it, because gnome-shell
  # only scans for extensions when it starts, so a freshly installed one
  # doesn't exist as far as any tool or setting is concerned until the
  # next login anyway. See the header for why it is worth turning on.
  #
  #   gnome-extensions enable allowlockedremotedesktop@kamens.us
  environment.systemPackages = [ pkgs.gnomeExtensions.allow-locked-remote-desktop ];

  # Gated on the password file so it only runs for the user who set one
  # up, and not for the gdm greeter or other accounts.
  systemd.user.services.gnome-remote-desktop = {
    wantedBy = [ "gnome-session.target" ];
    unitConfig.ConditionPathExists = "%h/.config/remote-desktop/rdp-password";
  };

  # Screen-share mode keeps its settings in the user's dconf and its
  # credentials in the login keyring (libsecret). Reapplied every login so
  # a change in GNOME Settings doesn't stick. The keyring has to be
  # unlocked, which a password login at GDM does; a fingerprint login
  # leaves it locked and the host would show an unlock prompt.
  #
  # Port negotiation is off so a taken port is an error, not a silent move
  # to some other port.
  systemd.user.services.gnome-remote-desktop-setup = {
    description = "Configure GNOME Remote Desktop to share the live session";
    wantedBy = [ "gnome-session.target" ];
    before = [ "gnome-remote-desktop.service" ];
    unitConfig.ConditionPathExists = "%h/.config/remote-desktop/rdp-password";
    path = [ pkgs.openssl pkgs.gnome-remote-desktop ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    # Self-signed is fine: RDP clients pin the fingerprint on first connect.
    script = ''
      certs="$HOME/.local/share/gnome-remote-desktop/certificates"
      if [ ! -s "$certs/rdp-tls.key" ] || [ ! -s "$certs/rdp-tls.crt" ]; then
        mkdir -p "$certs"
        openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -sha256 \
          -subj "/CN=${config.networking.hostName}" \
          -keyout "$certs/rdp-tls.key" -out "$certs/rdp-tls.crt" 2>/dev/null
        chmod 600 "$certs/rdp-tls.key"
      fi
      grdctl rdp set-tls-cert "$certs/rdp-tls.crt"
      grdctl rdp set-tls-key "$certs/rdp-tls.key"
      grdctl rdp set-port ${toString port}
      grdctl rdp disable-port-negotiation
      grdctl rdp disable-view-only
      grdctl rdp set-credentials "$USER" "$(< "$HOME/.config/remote-desktop/rdp-password")"
      grdctl rdp enable
    '';
  };
}
