# T3 Code (https://t3.codes): a web UI for driving coding agents (Claude
# Code, Codex, ...) on this machine, reachable from my other devices over the
# tailnet.
#
# The server runs as a systemd user service for carl (lingering is enabled in
# carl.nix, so it starts at boot) on port 3773 and serves the web UI itself:
# open http://<host>:3773 from any tailnet device. One browser tab can add the
# other hosts as environments under Settings -> Connections, so a single UI
# drives agents on every machine that imports this module.
#
# Upstream's own installer (`t3 service install`, `t3 update`) downloads
# releases into ~/.t3 and self-updates; don't use it here. The package comes
# from nixpkgs, so every host built from the same flake.lock runs the same
# version, and clients complain when server versions disagree.
#
# Pairing a device: every server start prints a one-time admin pairing link
# (valid for 5 minutes) to the journal. Its host is the first LAN address,
# which the firewall blocks; swap in the tailnet name, keeping the
# #token=... part:
#
#   systemctl --user restart t3code
#   journalctl --user -u t3code -n 40 | grep 'Pairing URL'
#   -> http://<host>:3773/pair#token=...
#
# Pair the first device that way: it gets admin rights, so it can mint links
# for other devices and revoke sessions in Settings -> Connections. From the
# shell, `t3 auth pairing create --base-url http://<host>:3773` also mints a
# link, but without admin rights; `t3 auth --help` manages sessions.
# (`t3 pair` mints the same kind of link but always advertises the LAN
# address, so it needs the same host swap.)
#
# Agents run as carl with carl's PATH: on start the server reads PATH from
# the login shell (fish -ilc) and puts it ahead of the unit's own PATH, so
# `claude` resolves exactly as it does in a terminal, and ~/.local/bin wins
# (paths.fish prepends it). A leftover native-installer ~/.local/bin/claude
# therefore shadows the nixpkgs one here too. Check which one T3 found under
# Settings -> Providers, which shows the version. Claude uses the normal
# ~/.claude login.
#
# State (threads, settings, auth sessions) lives in ~/.t3/userdata.
{ config, lib, pkgs, nixpkgs-master, ... }:
let
  user = "carl";
  port = 3773;
  tailnet = config.services.tailscale.interfaceName;

  # From the channel rather than nixpkgs-master: the Electron/pnpm build is
  # heavy, and the channel only advances once Hydra has cached it. Codex is
  # on by default in the package but not used here. claude-code (the same
  # nixpkgs-master build defaults.nix installs) goes on the wrapper's PATH as
  # a fallback for when reading the login shell fails; see above for why it
  # doesn't otherwise take precedence.
  t3code = pkgs.t3code.override {
    enableClaude = true;
    claude-code = nixpkgs-master.claude-code;
    enableCodex = false;
  };

  # Just the `t3` CLI and its completions, leaving out the t3code-desktop
  # Electron app and its menu entry. The desktop app starts its own backend
  # on the same ~/.t3/userdata as the service, so launching it on a host that
  # runs the service would put two servers on one database. Use the browser.
  t3cli = pkgs.runCommand "t3-cli-${t3code.version}" { } ''
    mkdir -p $out/bin $out/share
    ln -s ${t3code}/bin/t3 $out/bin/t3
    ln -s ${t3code}/share/{bash-completion,fish,zsh} $out/share/
  '';
in
{
  # For `t3 auth`, `t3 project`, and `t3 pair` against the running server.
  # These read the same ~/.t3 as the service.
  environment.systemPackages = [ t3cli ];

  systemd.user.services.t3code = {
    description = "T3 Code server";
    wantedBy = [ "default.target" ];
    unitConfig = {
      # User units are installed for every account; only run for carl.
      ConditionUser = user;
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };
    environment = {
      # PostHog product analytics are on by default.
      T3CODE_TELEMETRY_ENABLED = "false";
    };
    serviceConfig = {
      # "::" listens on both IPv4 and IPv6, so MagicDNS names work whichever
      # address the client picks. An explicit wildcard (rather than no --host)
      # is also what makes the server treat itself as remote-reachable. The
      # port is pinned because without --port it silently moves to the next
      # free one when 3773 is taken.
      ExecStart = "${t3code}/bin/t3 serve --host :: --port ${toString port}";
      WorkingDirectory = "%h";

      # The following mirror the unit upstream's `t3 service install` writes.
      # Let the server stop its agents gracefully before the rest of the
      # cgroup is killed.
      KillMode = "mixed";
      # Agent tool calls run inside this unit's cgroup. With the default
      # OOMPolicy=stop, the kernel OOM-killing one greedy child would take
      # down the server and every other running agent with it.
      OOMPolicy = "continue";
      Restart = "always";
      RestartSec = 5;
    };
  };

  # Tailnet only. tailscale0 is already a trusted interface (defaults.nix), so
  # this just records the intent in case that ever changes. The port stays
  # closed on the LAN.
  networking.firewall.interfaces.${tailnet}.allowedTCPPorts = [ port ];
}
