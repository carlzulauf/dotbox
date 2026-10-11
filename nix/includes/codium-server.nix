# VSCodium in the browser: editor, file explorer (with upload/download) and
# integrated terminal for this machine, on the tailnet over HTTPS at
# https://<host>.<tailnet>:4444 (see tailnet-https.nix). Pairs with
# web-terminal.nix for a full-screen terminal. The package is VSCodium's own
# web server (../pkgs/codium-server), so no Copilot and extensions come from
# Open VSX.
#
# Open a folder from the welcome page, or straight from the URL:
#   https://<host>.<tailnet>:4444/?folder=/home/carl/projects/dotbox
#
# Runs as a carl user service (lingering is on in carl.nix). The server starts
# from a fish login shell, because the unit's own PATH is minimal: this way
# extensions, language servers and the integrated terminal see the same PATH
# as a normal terminal (~/.local/bin first, gems, etc).
#
# --without-connection-token: the tailnet ACLs are the gate. Settings,
# extensions and server logs live in ~/.vscodium-server, separate from desktop
# VSCodium's ~/.config/VSCodium.
{ config, lib, pkgs, ... }:
let
  user = "carl";
  port = 4444;
  codium-server = pkgs.callPackage ../pkgs/codium-server { };

  start = pkgs.writeShellScript "codium-server-start" ''
    exec ${pkgs.fish}/bin/fish --login -c 'exec ${lib.getExe codium-server} $argv' -- \
      --host 127.0.0.1 \
      --port ${toString port} \
      --without-connection-token \
      --accept-server-license-terms \
      --disable-telemetry
  '';
in
{
  imports = [ ./tailnet-https.nix ];

  dotbox.tailnetHttps.services.codium-server.port = port;

  systemd.user.services.codium-server = {
    description = "VSCodium web server";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = user;
    serviceConfig = {
      ExecStart = start;
      WorkingDirectory = "%h";
      # Terminals and language servers run in this unit's cgroup; don't let
      # one OOM kill take the server and every open editor down with it.
      KillMode = "mixed";
      OOMPolicy = "continue";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
