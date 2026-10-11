# Browser terminal for this machine via ttyd (https://github.com/tsl0922/ttyd),
# on the tailnet over HTTPS at https://<host>.<tailnet>:7681 (see
# tailnet-https.nix).
#
# Each browser tab gets a fresh fish login shell in ~, like opening a new
# terminal window. tmux works as usual from there: `tmux attach` (or
# `tmux attach -t work`) joins the same sessions as desktop and ssh terminals,
# since this runs as carl and shares /tmp/tmux-1000/default. Closing the tab
# hangs up the shell, so anything not inside tmux ends with it; ttyd asks
# before letting the tab close.
#
# Runs as a carl user service (lingering is on in carl.nix) rather than the
# nixpkgs services.ttyd module, which is a single system unit that defaults
# to root + login(1). The shell is a login shell because the unit's own PATH
# is minimal; fish --login rebuilds the full one (~/.local/bin first, gems,
# etc), which a tmux server started from here inherits too.
{ config, lib, pkgs, ... }:
let
  user = "carl";
  port = 7681;
  host = config.networking.hostName;
in
{
  imports = [ ./tailnet-https.nix ];

  dotbox.tailnetHttps.services.ttyd.port = port;

  systemd.user.services.ttyd = {
    description = "ttyd web terminal";
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = user;
    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.ttyd}/bin/ttyd"
        "--interface" "lo"
        "--port" (toString port)
        "--writable"
        # Refuse websockets opened by other sites' pages. tailscale serve
        # passes the browser's Host through, so the origin still matches.
        "--check-origin"
        "--client-option" "titleFixed=${host}"
        "${pkgs.fish}/bin/fish" "--login"
      ];
      WorkingDirectory = "%h";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
