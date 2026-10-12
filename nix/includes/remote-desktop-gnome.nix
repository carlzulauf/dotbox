# Remote desktop between my machines over the tailnet, using RDP. This is the
# GNOME side, imported by gnome.nix; khoa's Plasma gets
# remote-desktop-plasma.nix instead.
#
# Every machine answers on two ports, and they mean different things:
#
#   3390  Live session. gnome-remote-desktop in screen-share mode shares the
#         desktop that is already running on the physical display, exactly
#         as it was left. It only listens while that user is logged in, so
#         an open 3390 means "there is a session to share".
#   3389  Remote Login. The gnome-remote-desktop system daemon hands the
#         connection to a headless GDM greeter; logging in there starts a
#         fresh headless session, which keeps running after disconnecting
#         and is resumed on the next connection. End it with Log Out in the
#         system menu (gnome.nix makes it always show), never Power Off,
#         which takes the whole machine down. Don't use 3389 on a machine
#         with a local session: GNOME can't share a session between the
#         display and a remote login, so GDM offers to kill the local one
#         instead.
#
# Clients connect with GNOME Connections, with each host:port added by hand.
#
# One-time setup per machine: put the RDP password (the secret for the RDP
# connection itself, not an account password) in
# ~/.config/remote-desktop/rdp-password. Both daemons read it; without it
# they have no credentials and refuse every connection.
#
# Sharing a live session needs that session unlocked: mutter closes and
# refuses screen-share sessions while the lock screen is up ("Session
# creation inhibited"), so an idle machine stops answering on 3390 - which is
# exactly when it's usually being connected to. The Allow Locked Remote
# Desktop extension installed below lifts that restriction (it runs in the
# "unlock-dialog" session mode); connecting to a locked host then shows its
# lock screen, which still wants the account password. It has to be enabled
# by hand once per machine. Until it is, a locked host can be opened up with:
#
#   ssh -t <host> sudo loginctl unlock-session <id>   # id from loginctl
#
# VNC is not used: it is slower, and gnome-remote-desktop only offers
# password auth for it in screen-share mode, with no Remote Login. SPICE is a
# QEMU guest protocol with no server for a physical desktop.
{ config, lib, pkgs, ... }:
let
  user = "carl";
  passwordFile = "${config.users.users.${user}.home}/.config/remote-desktop/rdp-password";

  loginPort = 3389;
  livePort = 3390;

  # Home of the gnome-remote-desktop system user (created by its tmpfiles.d).
  grdStateDir = "/var/lib/gnome-remote-desktop";

  # Self-signed is fine: RDP clients pin the fingerprint on first connect.
  makeCert = dir: ''
    if [ ! -s "${dir}/rdp-tls.key" ] || [ ! -s "${dir}/rdp-tls.crt" ]; then
      mkdir -p "${dir}"
      openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -sha256 \
        -subj "/CN=${config.networking.hostName}" \
        -keyout "${dir}/rdp-tls.key" -out "${dir}/rdp-tls.crt" 2>/dev/null
      chmod 600 "${dir}/rdp-tls.key"
    fi
  '';
in
{
  services.gnome.gnome-remote-desktop.enable = true;

  # Installed, but left switched off: enable it by hand once per machine,
  # like the other extensions. Nothing here can do it, because gnome-shell
  # only scans for extensions when it starts, so a freshly installed one
  # doesn't exist as far as any tool or setting is concerned until the
  # next login anyway. See the header for why it is worth turning on.
  #
  #   gnome-extensions enable allowlockedremotedesktop@kamens.us
  environment.systemPackages = [ pkgs.gnomeExtensions.allow-locked-remote-desktop ];

  # --- 3389: Remote Login (system daemon) ---

  # The daemon reads these four keys and nothing else from grd.conf.
  environment.etc."gnome-remote-desktop/grd.conf".text = ''
    [RDP]
    enabled=true
    port=${toString loginPort}
    tls-cert=${grdStateDir}/rdp-tls.crt
    tls-key=${grdStateDir}/rdp-tls.key
  '';

  # Upstream installs this WantedBy=graphical.target, but NixOS ignores
  # [Install] sections, and `grdctl --system rdp enable` can't write the
  # symlink into the read-only /etc/systemd.
  systemd.services.gnome-remote-desktop.wantedBy = [ "graphical.target" ];

  systemd.services.gnome-remote-desktop-setup = {
    description = "Seed GNOME Remote Desktop TLS certificate and RDP credentials";
    wantedBy = [ "graphical.target" ];
    before = [ "gnome-remote-desktop.service" ];
    path = [ pkgs.openssl pkgs.gnome-remote-desktop pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 700 -o gnome-remote-desktop -g gnome-remote-desktop ${grdStateDir}
      ${makeCert grdStateDir}
      chown gnome-remote-desktop:gnome-remote-desktop ${grdStateDir}/rdp-tls.key ${grdStateDir}/rdp-tls.crt

      # Credentials live in the TPM, or in credentials.ini where there is
      # none. They go to grdctl as arguments because it segfaults reading
      # them from a non-tty stdin; that exposes them in the process list
      # for the moment this runs.
      #
      # Not `grdctl --system`: that re-runs itself as
      # `pkexec --user gnome-remote-desktop grdctl ...`, which fails here
      # with "Failed to execute child process pkexec" (the setuid wrapper
      # dir isn't on a unit's PATH) and would then depend on polkit
      # authorising a root caller with no agent. grdctl already selects
      # system mode when its own euid is the daemon's user
      # (grd-ctl.c: `geteuid () == pw->pw_uid`), so becoming that user
      # first does the same work with no polkit involved. HOME must be set
      # explicitly: grdctl stores credentials under $HOME/.local/share,
      # and root's HOME would put them where the daemon never looks.
      if [ -r ${passwordFile} ]; then
        runuser -u gnome-remote-desktop -- \
          env HOME=${grdStateDir} grdctl rdp set-credentials ${user} "$(< ${passwordFile})"
      else
        echo "${passwordFile} is missing: Remote Login will refuse all connections" >&2
      fi

      # grdctl and GNOME Settings write settings to this local-state file,
      # which overrides /etc/gnome-remote-desktop/grd.conf. Drop it so
      # neither can shadow the config above.
      rm -f ${grdStateDir}/.local/share/gnome-remote-desktop/grd.conf
    '';
  };

  # Remote Login moves the RDP connection from the system daemon into the
  # headless GDM greeter, then into the session started from it. Each of
  # those needs this handover daemon running. Upstream's WantedBy is lost
  # the same way as above, so without this the login stalls after the
  # greeter.
  systemd.user.services.gnome-remote-desktop-handover.wantedBy = [ "gnome-session.target" ];

  # --- 3390: live session (per-user screen-share daemon) ---

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
    script = ''
      certs="$HOME/.local/share/gnome-remote-desktop/certificates"
      ${makeCert "$certs"}
      grdctl rdp set-tls-cert "$certs/rdp-tls.crt"
      grdctl rdp set-tls-key "$certs/rdp-tls.key"
      grdctl rdp set-port ${toString livePort}
      grdctl rdp disable-port-negotiation
      grdctl rdp disable-view-only
      grdctl rdp set-credentials "$USER" "$(< "$HOME/.config/remote-desktop/rdp-password")"
      grdctl rdp enable
    '';
  };
}
