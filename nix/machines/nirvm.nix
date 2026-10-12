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
# ~/.config/remote-desktop/rdp-password from dotbox-private. Only encrypted
# security types are offered: RSA-AES, and VeNCrypt with a self-signed
# certificate. TigerVNC's vncviewer works (RSA-AES, accept the key
# fingerprint on first connect). GNOME Connections does not: gtk-vnc has no
# RSA-AES and fails VeNCrypt's certificate setup.
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
  reframeStateDir = "/var/lib/reframe";
  rdpPasswordFile = "${home}/.config/remote-desktop/rdp-password";
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
    description = "Write ReFrame's config and TLS/RSA keys";
    path = [ pkgs.openssl ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ ! -s ${rdpPasswordFile} ]; then
        echo "${rdpPasswordFile} is missing: not starting the VNC server" >&2
        exit 1
      fi

      install -d -m 750 -o root -g reframe ${reframeStateDir}
      cd ${reframeStateDir}

      # Self-signed is fine: VNC clients pin the certificate on first connect.
      if [ ! -s tls.key ] || [ ! -s tls.crt ]; then
        openssl req -x509 -newkey rsa:4096 -nodes -days 3650 -sha256 \
          -subj "/CN=${config.networking.hostName}" \
          -keyout tls.key -out tls.crt 2>/dev/null
      fi
      # RSA-AES (RA2) needs a PKCS#1 key, the "traditional" format.
      [ -s rsa.key ] || openssl genrsa -traditional -out rsa.key 4096 2>/dev/null
      chown root:reframe tls.key tls.crt rsa.key
      chmod 640 tls.key tls.crt rsa.key

      # Rewritten every boot so a changed password is picked up. The
      # [reframe] defaults find the first connected display on their own.
      install -d -m 750 -o root -g reframe /etc/reframe
      install -m 640 -o root -g reframe /dev/stdin /etc/reframe/${reframeInstance}.conf <<EOF
      [reframe]
      damage=cpu
      fps=30

      [vnc]
      port=${toString vncPort}
      backend=neatvnc
      password=$(< ${rdpPasswordFile})

      [neatvnc]
      username=${user}
      allow-broken-crypto=false
      rsa-private-key-file=${reframeStateDir}/rsa.key
      tls-private-key-file=${reframeStateDir}/tls.key
      tls-certificate-file=${reframeStateDir}/tls.crt
      EOF
    '';
  };

  # Open to the LAN as well as the tailnet (trusted everywhere already).
  networking.firewall.allowedTCPPorts = [ vncPort ];

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "26.11";
}
