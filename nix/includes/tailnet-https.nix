# Shared helper for the web-app modules (web-terminal.nix, codium-server.nix,
# cockpit.nix, filebrowser.nix): publishes a localhost-only app to the
# tailnet over HTTPS with `tailscale serve`.
#
# The app binds 127.0.0.1:<port>, and tailscale serve answers on
# <tailnet IP>:<same port> with a real *.ts.net certificate, proxying to it.
# Sharing the port number is fine: tailscaled intercepts serve traffic in its
# own netstack before the kernel sees it, so the two never collide. The app is
# never reachable from the LAN, and no firewall rule is needed.
#
# HTTPS isn't decoration here: plain http://<host>:<port> is not a "secure
# context", so browsers withhold the clipboard API, service workers and PWA
# install, and VS Code webviews break. The cert only covers the full
# name, so use https://<host>.<domain>:<port> (each service's `url` below);
# bare https://<host>:<port> fails the name check. The first request after a
# cert expires stalls a few seconds while tailscaled fetches a new one.
#
# Access is decided by the tailnet ACLs alone, as with t3code.nix: these apps
# have no login of their own (Cockpit excepted, which uses PAM).
#
# Serve config persists in tailscaled's state; each unit re-applies it at boot
# and removes it when stopped, so dropping a module from a machine also
# withdraws its port. Inspect with `tailscale serve status`.
{ config, lib, pkgs, ... }:
let
  cfg = config.dotbox.tailnetHttps;
  host = config.networking.hostName;
  tailscale = "${config.services.tailscale.package}/bin/tailscale";
in
{
  options.dotbox.tailnetHttps = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "taila7d3f.ts.net";
      description = "MagicDNS suffix of the tailnet (`tailscale status --json | jq .MagicDNSSuffix`).";
    };

    services = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            description = "Port the app listens on at 127.0.0.1, and the HTTPS port on the tailnet.";
          };
          url = lib.mkOption {
            type = lib.types.str;
            readOnly = true;
            default = "https://${host}.${cfg.domain}:${toString config.port}";
            description = "Tailnet URL of the app.";
          };
        };
      }));
    };
  };

  config.systemd.services = lib.mapAttrs' (name: svc:
    lib.nameValuePair "tailnet-https-${name}" {
      description = "Serve ${name} on the tailnet at ${svc.url}";
      wantedBy = [ "multi-user.target" ];
      wants = [ "tailscaled.service" ];
      after = [ "tailscaled.service" ];
      unitConfig = {
        StartLimitIntervalSec = 600;
        StartLimitBurst = 10;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # tailscaled can be up but not yet logged in / Running at boot.
        ExecStartPre = "${tailscale} wait --timeout=2m";
        ExecStart = "${tailscale} serve --bg --https=${toString svc.port} http://127.0.0.1:${toString svc.port}";
        ExecStop = "${tailscale} serve --https=${toString svc.port} off";
        Restart = "on-failure";
        RestartSec = 30;
      };
    }
  ) cfg.services;
}
