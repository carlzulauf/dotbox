# Cockpit (https://cockpit-project.org) web console with cockpit-files, on
# the tailnet over HTTPS at https://<host>.<tailnet>:9090 (see
# tailnet-https.nix). Log in with carl's Unix password (PAM).
#
# One login covers: Terminal (run `tmux attach` there), Files (browse,
# upload/download, permissions, a basic editor with Ctrl-S save), plus
# services, logs, storage, networking and metrics.
#
# tv.nix also enables Cockpit on 9090 for its machines; this layers on top.
# Cockpit moves to 127.0.0.1 here, so on hosts that import this module the old
# http://<host>:9090 stops answering in favor of the HTTPS URL.
#
# Logging into other hosts from the login page (WebService.LoginTo) stays at
# the module's default of off.
{ config, lib, pkgs, ... }:
let
  port = 9090;
in
{
  imports = [ ./tailnet-https.nix ];

  dotbox.tailnetHttps.services.cockpit.port = port;

  services.cockpit = {
    enable = true;
    inherit port;
    plugins = [ pkgs.cockpit-files ];
    # The motd/issue banner advertises https://<host>:9090, which is no
    # longer the address.
    showBanner = false;
    # cockpit-ws rejects websockets whose Origin isn't listed.
    allowed-origins = [ config.dotbox.tailnetHttps.services.cockpit.url ];
    settings.WebService = {
      # tailscale serve terminates TLS and talks plain HTTP to 127.0.0.1.
      AllowUnencrypted = true;
      ProtocolHeader = "X-Forwarded-Proto";
      ForwardedForHeader = "X-Forwarded-For";
    };
  };

  # The module listens on all interfaces; keep it on loopback behind serve.
  # The leading "" clears the ListenStream from upstream's cockpit.socket.
  systemd.sockets.cockpit.listenStreams = lib.mkForce [
    ""
    "127.0.0.1:${toString port}"
  ];
}
