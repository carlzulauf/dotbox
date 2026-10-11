# FileBrowser Quantum (https://github.com/gtsteffaniak/filebrowser): web file
# manager with indexed search, previews, uploads and a built-in text editor,
# on the tailnet over HTTPS at https://<host>.<tailnet>:8088 (see
# tailnet-https.nix).
#
# This is the maintained fork. The original filebrowser/filebrowser (the one
# nixpkgs' services.filebrowser module runs) was archived on 2026-09-01 and
# gets no more fixes. nixpkgs has no module for Quantum, hence this one.
#
# Runs as a carl user service, so it reads and writes files exactly as carl
# does. Sources are carl's home plus dotbox.filebrowser.extraSources (machine
# configs add shares there). Each source is indexed in the background for
# search; the first scan of a big tree takes a while.
#
# Auth is off (noauth): the tailnet ACLs are the gate, and every visitor is the
# built-in admin user "carl" (created with the database, on first start). The
# database, holding that user and its UI preferences, lives in
# ~/.local/state/filebrowser-quantum; server settings come from the config
# generated below, read on every start. Sources added later show up for the
# existing user on the next start (defaultEnabled).
{ config, lib, pkgs, ... }:
let
  user = "carl";
  port = 8088;
  home = config.users.users.${user}.home;
  stateDir = "${home}/.local/state/filebrowser-quantum";
  cacheDir = "${home}/.cache/filebrowser-quantum";

  source = path: name: {
    inherit path name;
    # Show the source to the (single) user without granting it by hand.
    config.defaultEnabled = true;
  };

  settings = {
    server = {
      listen = "127.0.0.1";
      inherit port;
      database = "${stateDir}/database.db";
      inherit cacheDir;
      cacheDirCleanup = true;
      # Used in share links.
      externalUrl = config.dotbox.tailnetHttps.services.filebrowser.url;
      disableUpdateCheck = true;
      sources =
        [ (source home "home") ]
        ++ lib.mapAttrsToList (name: path: source path name) config.dotbox.filebrowser.extraSources;
    };
    auth = {
      adminUsername = user;
      methods = {
        noauth = true;
        password.enabled = false;
      };
    };
  };

  configFile = (pkgs.formats.yaml { }).generate "filebrowser-quantum.yaml" settings;
in
{
  imports = [ ./tailnet-https.nix ];

  options.dotbox.filebrowser.extraSources = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    example = { files = "/mnt/files/carl"; };
    description = "Extra directories to browse, as display name -> path.";
  };

  config = {
    dotbox.tailnetHttps.services.filebrowser.port = port;

    systemd.user.services.filebrowser-quantum = {
      description = "FileBrowser Quantum";
      wantedBy = [ "default.target" ];
      unitConfig.ConditionUser = user;
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.filebrowser-quantum} -c ${configFile}";
        # ~/.local/state/... and ~/.cache/... for a user unit.
        StateDirectory = "filebrowser-quantum";
        CacheDirectory = "filebrowser-quantum";
        WorkingDirectory = stateDir;
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
