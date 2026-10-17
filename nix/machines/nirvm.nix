# nirvm: a VM for trying out niri, riced with DankMaterialShell
# (includes/niri-dms.nix). It runs on frix for now, but nothing here is tied
# to frix: bin/nirvm builds the disk image from this config and creates the
# libvirt domain on whichever host runs it.
#
# Once it's running it's an ordinary machine, updated from inside with
# `bin/install_nix --switch` like the rest. bin/nirvm only creates it.
#
# First boot: bin/nirvm attaches a seed disk (an ISO labelled NIRVM-SEED)
# holding the account password, copies of the repos, and optionally a
# tailscale auth key. nirvm-provision below applies it once, before the
# greeter starts, then never runs again.
#
# Remote desktop: VNC on port 5900, served by ReFrame. It reads the
# framebuffer through DRM and types through uinput, which the other options
# can't: wayvnc's virtual keyboard bypasses niri's keybinds entirely
# (niri-wm/niri#403), gnome-remote-desktop needs mutter, and krdp needs
# KWin. Being below the compositor it also shows the greeter, so the VM can
# be logged into remotely. Reachable on the LAN (the VM has its own LAN
# address via macvtap) and the tailnet. Credentials are carl and the same
# password the RDP setup uses on the other machines,
# ~/.config/remote-desktop/rdp-password from dotbox-private. It uses classic
# VNC password auth (libvncserver backend) with no encryption, which is fine
# on the home LAN and the tailnet and is what GNOME Connections (gtk-vnc)
# supports. Only the first 8 characters of the password count, and there is
# no username.
#
# The libvirt console (virt-manager or virt-viewer over qemu+ssh://<host>)
# stays available too, for when the guest itself is in trouble.
{ config, lib, pkgs, ... }:
let
  user = "carl";
  home = config.users.users.${user}.home;

  seedLabel = "NIRVM-SEED";
  provisionedStamp = "/var/lib/nirvm/provisioned";

  vncPort = 5900;
  reframeInstance = "main";
  rdpPasswordFile = "${home}/.config/remote-desktop/rdp-password";

  # Every cursor in this theme is a single transparent pixel.
  invisibleCursorThemeName = "nirvm-invisible";
  invisibleCursorTheme = pkgs.runCommand "nirvm-invisible-cursor-theme"
    {
      nativeBuildInputs = [ pkgs.xcursorgen pkgs.imagemagick ];
      # CSS names (what cursor-shape-v1 asks for) plus the legacy X names.
      names = ''
        default context-menu help pointer progress wait cell crosshair text
        vertical-text alias copy move no-drop not-allowed grab grabbing
        all-scroll col-resize row-resize n-resize e-resize s-resize w-resize
        ne-resize nw-resize se-resize sw-resize ew-resize ns-resize nesw-resize
        nwse-resize zoom-in zoom-out dnd-ask dnd-none dnd-copy dnd-move dnd-link
        left_ptr arrow top_left_arrow xterm ibeam hand1 hand2 watch
        left_ptr_watch question_arrow crossed_circle pirate fleur size_all
        sb_h_double_arrow sb_v_double_arrow size_hor size_ver size_bdiag
        size_fdiag split_h split_v top_side bottom_side left_side right_side
        top_left_corner top_right_corner bottom_left_corner bottom_right_corner
        plus cross X_cursor openhand closedhand
      '';
    } ''
    dir=$out/share/icons/${invisibleCursorThemeName}
    mkdir -p $dir/cursors
    magick -size 1x1 xc:none empty.png
    echo "1 0 0 empty.png" > empty.cfg
    xcursorgen empty.cfg $dir/cursors/left_ptr
    for name in $names; do
      [ -e $dir/cursors/$name ] || ln -s left_ptr $dir/cursors/$name
    done
    printf '[Icon Theme]\nName=${invisibleCursorThemeName}\n' > $dir/index.theme
  '';

  # Switches niri between the invisible theme and whatever cursor it had
  # before, by rewriting a file that config.kdl includes last. niri reloads
  # it on change.
  nirvmCursor = pkgs.writeShellApplication {
    name = "nirvm-cursor";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
    text = ''
      niri_dir=''${XDG_CONFIG_HOME:-$HOME/.config}/niri
      config=$niri_dir/config.kdl
      cursor_file=$niri_dir/nirvm-cursor.kdl
      include='include optional=true "nirvm-cursor.kdl"'
      theme=${invisibleCursorThemeName}

      usage() {
        echo "usage: nirvm-cursor [toggle|hide|show|status|init]"
        echo "Hides niri's cursor for remote desktop (VNC draws its own) or shows it"
        echo "again for the libvirt console. Mod+Shift+C toggles it too."
      }

      state() {
        if grep -qF "xcursor-theme \"$theme\"" "$cursor_file" 2>/dev/null; then
          echo hidden
        else
          echo shown
        fi
      }

      write() {
        {
          echo "// Written by nirvm-cursor (see nix/machines/nirvm.nix); edits are lost."
          echo "binds {"
          echo "    Mod+Shift+C hotkey-overlay-title=\"Toggle cursor (hide for VNC)\" { spawn \"nirvm-cursor\" \"toggle\"; }"
          echo "}"
          if [ "$1" = hidden ]; then
            echo "cursor {"
            echo "    xcursor-theme \"$theme\""
            echo "}"
          fi
        } > "$cursor_file.tmp"
        mv "$cursor_file.tmp" "$cursor_file"
      }

      # Hooks the file into niri's config (last, so it overrides DMS's
      # cursor settings) and creates it shown, if either is missing.
      init() {
        [ -e "$config" ] || { echo "$config doesn't exist yet" >&2; exit 1; }
        if ! grep -qxF "$include" "$config"; then
          printf '\n// Cursor toggle for remote desktop, see nirvm-cursor\n%s\n' "$include" >> "$config"
        fi
        [ -e "$cursor_file" ] || write shown
      }

      case "''${1:-toggle}" in
        init) init ;;
        hide) init; write hidden; state ;;
        show) init; write shown; state ;;
        toggle)
          init
          if [ "$(state)" = hidden ]; then write shown; else write hidden; fi
          state
          ;;
        status) state ;;
        -h|--help|help) usage ;;
        *) usage >&2; exit 2 ;;
      esac
    '';
  };
in
{
  networking.hostName = "nirvm";

  imports =
    [
      ../includes/gui.nix
      ../includes/niri-dms.nix
    ];

  # Lets the host see the guest's addresses (`virsh domifaddr nirvm --source
  # agent`) and shut it down cleanly.
  services.qemuGuest.enable = true;

  # same as frix, its host
  time.timeZone = "America/Chicago";

  # A throwaway test box that agents drive over ssh, so no sudo passwords
  # (carl is the only wheel user).
  security.sudo.wheelNeedsPassword = false;

  # --- First boot provisioning ---

  systemd.services.nirvm-provision = {
    description = "Provision nirvm from its seed disk";
    wantedBy = [ "multi-user.target" ];
    # the password has to be set before anyone can log in at the greeter,
    # and the RDP password file has to exist before ReFrame is configured
    before = [ "greetd.service" "reframe-setup.service" ];
    # network only for `tailscale up`
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "tailscaled.service" ];
    unitConfig.ConditionPathExists = "!${provisionedStamp}";
    path = with pkgs; [ coreutils util-linux shadow ruby_4_0 config.services.tailscale.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      seed=/dev/disk/by-label/${seedLabel}
      for _ in $(seq 30); do
        [ -e "$seed" ] && break
        sleep 1
      done
      if [ ! -e "$seed" ]; then
        # Not marked done, so attaching a seed disk and rebooting retries.
        echo "No seed disk labelled ${seedLabel}; nothing to provision." >&2
        exit 0
      fi

      mnt=$(mktemp -d)
      mount -o ro "$seed" "$mnt"
      trap 'umount "$mnt"; rmdir "$mnt"' EXIT

      if [ -s "$mnt/password.hash" ]; then
        usermod --password "$(< "$mnt/password.hash")" ${user}
      fi

      # bin/nirvm put each repo there as a clone with the branch to use
      # checked out and origin already pointing upstream.
      install -d -o ${user} -g users ${home}/projects
      for repo in "$mnt"/repos/*/; do
        name=$(basename "$repo")
        dest=${home}/projects/$name
        if [ -e "$dest" ]; then
          echo "Keeping existing $dest"
          continue
        fi
        cp -a "$repo" "$dest"
        chown -R ${user}:users "$dest"
      done

      if [ -x ${home}/projects/dotbox/bin/install_dotfiles ]; then
        runuser -u ${user} -- env HOME=${home} \
          ${home}/projects/dotbox/bin/install_dotfiles --yes
      fi

      if [ -s "$mnt/tailscale-authkey" ]; then
        tailscale up --auth-key="file:$mnt/tailscale-authkey" --hostname=${config.networking.hostName} \
          || echo "tailscale up failed; run it by hand" >&2
      fi

      install -D -m 644 /dev/null ${provisionedStamp}
    '';
  };

  # --- Remote desktop (ReFrame VNC) ---

  # The module only installs ReFrame and its units; configs is left empty
  # because it would put the password in the world-readable store.
  # reframe-setup writes the config from the RDP password file instead.
  services.reframe.enable = true;

  systemd.services."reframe-server@${reframeInstance}" = {
    # Only the template ships in the package, so without this NixOS writes
    # a whole unit with no ExecStart instead of extending the template.
    overrideStrategy = "asDropin";
    wantedBy = [ "multi-user.target" ];
    requires = [ "reframe-setup.service" ];
    after = [ "reframe-setup.service" ];
  };

  systemd.services.reframe-setup = {
    description = "Write ReFrame's config";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s ${rdpPasswordFile} ]; then
        echo "${rdpPasswordFile} is missing: not starting the VNC server" >&2
        exit 1
      fi

      # Rewritten every boot so a changed password is picked up. The
      # [reframe] defaults find the first connected display on their own.
      install -d -m 750 -o root -g reframe /etc/reframe
      install -m 640 -o root -g reframe /dev/stdin /etc/reframe/${reframeInstance}.conf <<EOF
      [reframe]
      damage=cpu
      fps=30

      [vnc]
      port=${toString vncPort}
      backend=libvncserver
      password=$(< ${rdpPasswordFile})
      EOF
    '';
  };

  # ReFrame can only paint niri's cursor into the frames it sends, where it
  # trails the VNC client's own pointer as a second cursor. And niri draws
  # the cursor into the picture itself on virtio-gpu (Smithay doesn't set
  # the hotspot cap that unlocks the cursor plane on virtual GPUs), so
  # ReFrame's cursor=false can't drop it. Instead `nirvm-cursor hide` (or
  # Mod+Shift+C) makes niri's cursor invisible while using VNC, leaving
  # only the client's pointer, which never changes shape. `nirvm-cursor
  # show` brings it back for the libvirt console, where it's needed.
  # Apps that draw their own cursor (some X11 ones) still show theirs.
  environment.systemPackages = [ nirvmCursor invisibleCursorTheme ];

  systemd.user.services.nirvm-cursor-init = {
    description = "Hook nirvm-cursor's file into niri's config";
    wantedBy = [ "niri.service" ];
    before = [ "niri.service" ];
    after = [ "niri-dms-config.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nirvmCursor}/bin/nirvm-cursor init";
    };
  };

  # Open to the LAN as well as the tailnet (trusted everywhere already).
  networking.firewall.allowedTCPPorts = [ vncPort ];

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "26.11";
}
