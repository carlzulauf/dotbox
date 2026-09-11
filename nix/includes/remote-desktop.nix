# Remote desktop between my machines over the tailnet, using RDP.
#
# Every machine answers on two ports, and they mean different things:
#
#   3390  Live session. A per-user daemon shares the desktop that is already
#         running on the physical display, exactly as it was left (GNOME:
#         gnome-remote-desktop in screen-share mode, Plasma: krdp). It only
#         listens while that user is logged in, so an open 3390 means "there
#         is a session to share".
#   3389  Remote Login (GNOME only). The gnome-remote-desktop system daemon
#         hands the connection to a headless GDM greeter; logging in there
#         starts a fresh headless session, which keeps running after
#         disconnecting and is resumed on the next connection. Don't use it
#         on a machine with a local session: GNOME can't share a session
#         between the display and a remote login, so GDM offers to kill the
#         local one instead.
#
# `rdp <host>` picks between them: 3390 if it answers, otherwise 3389.
#
# One-time setup per machine: put the RDP password (the secret for the RDP
# connection itself, not an account password) in
# ~/.config/remote-desktop/rdp-password. Both GNOME daemons read it; without
# it they have no credentials and refuse every connection. Plasma's krdp
# ignores it and checks the real account password through PAM instead.
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

  gnome = config.services.desktopManager.gnome.enable;
  plasma = config.services.desktopManager.plasma6.enable;
  tailnet = config.services.tailscale.interfaceName;

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

  rdp = pkgs.writeShellApplication {
    name = "rdp";
    runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.gnome-connections ];
    text = ''
      usage() {
        echo "usage: rdp [--live|--login] <host>" >&2
        echo "  --live   share the session running on the host's display (port ${toString livePort})" >&2
        echo "  --login  GNOME Remote Login into a fresh/resumed headless session (port ${toString loginPort})" >&2
        exit 2
      }

      mode=auto
      case "''${1:-}" in
        --live) mode=live; shift ;;
        --login) mode=login; shift ;;
        -h|--help) usage ;;
      esac
      [ $# -eq 1 ] || usage
      host=$1

      # Offline tailnet peers swallow SYNs rather than refusing, so bound it.
      port_open() { timeout 2 bash -c ": </dev/tcp/$host/$1" 2>/dev/null; }

      case $mode in
        live) port=${toString livePort} ;;
        login) port=${toString loginPort} ;;
        auto)
          if port_open ${toString livePort}; then
            port=${toString livePort}
            echo "rdp: $host has a live session, sharing it (port $port)"
          elif port_open ${toString loginPort}; then
            port=${toString loginPort}
            echo "rdp: no live session on $host, using Remote Login (port $port)"
          else
            echo "rdp: $host answers on neither ${toString livePort} nor ${toString loginPort}" >&2
            exit 1
          fi
          ;;
      esac

      exec gnome-connections "rdp://$host:$port"
    '';
  };
in
{
  config = lib.mkMerge [
    {
      environment.systemPackages = [ rdp ];
      # Only reachable over the tailnet, never the LAN/public interfaces.
      networking.firewall.interfaces.${tailnet}.allowedTCPPorts = [ livePort ];
    }

    (lib.mkIf gnome {
      services.gnome.gnome-remote-desktop.enable = true;
      networking.firewall.interfaces.${tailnet}.allowedTCPPorts = [ loginPort ];

      # Mutter closes and refuses screen-share sessions whenever the lock
      # screen is up ("Session creation inhibited", meta-dbus-session-manager.c),
      # so sharing the live session stops working as soon as a machine idles
      # out - which is exactly when it is being connected to from elsewhere.
      # This extension lifts that restriction; it declares the "unlock-dialog"
      # session mode, which is what allows it to keep running while locked.
      # Connecting to a locked host then shows its lock screen, which still
      # demands the account password, so remote access is no easier than
      # walking up to the machine.
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
        after = [ "dbus.service" ];
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
        path = [ pkgs.openssl pkgs.gnome-remote-desktop pkgs.gnome-shell ];
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

          # Enabled here rather than from a dconf default, because the user's
          # own enabled-extensions list (which exists on every machine with
          # any extension turned on) overrides a system default entirely.
          # This edits that user list, and the shell acts on it immediately.
          gnome-extensions enable ${pkgs.gnomeExtensions.allow-locked-remote-desktop.extensionUuid}
        '';
      };
    })

    # Plasma has only the live-session half: krdp shares a running session,
    # and SDDM has no remote login, so a machine sitting at SDDM can't be
    # reached this way.
    (lib.mkIf plasma {
      # KConfig falls back to /etc/xdg for keys missing from ~/.config/krdpserverrc.
      # SystemUserEnabled checks the account password via PAM ("login").
      environment.etc."xdg/krdpserverrc".text = lib.generators.toINI { } {
        General = {
          ListenPort = livePort;
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
          ExecStart = "${pkgs.kdePackages.krdp}/bin/krdpserver --plasma --port ${toString livePort}";
          Restart = "on-abnormal";
        };
      };
    })
  ];
}
