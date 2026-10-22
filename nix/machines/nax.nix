{ config, pkgs, nixos-hardware, nixpkgs-master, ... }:

{
  # rebuild of znr
  # Ryzen 5700G
  # 32GB DDR4
  # (x2) 16TB Seagate IronWolf Pro SATA HDD
  # 4TB Crucial P4 NVMe SSD (boot)
  networking.hostName = "nax";

  imports =
    [
      nixos-hardware.nixosModules.common-cpu-amd
      nixos-hardware.nixosModules.common-cpu-amd-pstate
      # Breaking build on 2026/10/22
      # nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/tv.nix
    ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
    file # signal-decode-v2 identifies decrypted attachments with it

    # Transcribe old recordings: `transcribe a.m4a b.wav ...` writes .txt,
    # .srt, .vtt, .tsv and .json for each into the current directory. Any
    # whisperx option after the files overrides these defaults (last one
    # wins), e.g. --language es, --output_format txt, or speaker labels with
    # --diarize --hf_token <token>. CPU only, so slow but accurate: large-v3,
    # int8, 8 of the 16 threads, niced so jellyfin keeps priority.
    whisperx
    (writeShellScriptBin "transcribe" ''
      exec nice -n 10 ${whisperx}/bin/whisperx \
        --model large-v3 --device cpu --compute_type int8 --threads 8 \
        --language en --output_format all "$@"
    '')
  ];

  # nix.settings.substituters = [ "http://nax/" ];

  # This machine is a --build-host for other nix machines. If we let nix-daemon
  # pick the number of concurrent build jobs, this machine will often encounter
  # an OOM situation on larger build jobs. Limit the nuber of concurrent build
  # processes to just a couple, and the halve the number of cores from the max
  # so that jellyfin and other services have resources available.
  nix.settings = {
    max-jobs = 2;
    cores = 8;
  };

  # allow nax to build ARM packages (for raspberry pi or pine64)
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # lsblk --output NAME,SIZE,TYPE,MOUNTPOINTS,UUID
  fileSystems."/mnt/ocean1" = {
    device = "/dev/disk/by-uuid/3a2123a9-49bf-4786-b815-84e191158c3e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/files" = {
    device = "/dev/disk/by-uuid/3a2123a9-49bf-4786-b815-84e191158c3e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@files"
    ];
  };

  fileSystems."/mnt/vault" = {
    device = "/dev/disk/by-uuid/3a2123a9-49bf-4786-b815-84e191158c3e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@vault"
    ];
  };

  fileSystems."/mnt/downloads" = {
    device = "/dev/disk/by-uuid/3a2123a9-49bf-4786-b815-84e191158c3e";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@downloads"
    ];
  };

  fileSystems."/mnt/ocean2" = {
    device = "/dev/disk/by-uuid/0ee89dbe-0149-429e-9cb0-4481da7694d2";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/"
    ];
  };

  fileSystems."/mnt/backup" = {
    device = "/dev/disk/by-uuid/0ee89dbe-0149-429e-9cb0-4481da7694d2";
    fsType = "btrfs";
    options = [
      "defaults"
      "subvol=/@backup"
    ];
  };

  services.snapraid = {
    enable = true;

    parityFiles = [
      "/mnt/backup/snapraid.parity"
    ];

    dataDisks = {
      d1 = "/mnt/files";
      d2 = "/mnt/vault";
    };

    contentFiles = [
      "/mnt/backup/snapraid.content"
      "/mnt/ocean1/snapraid.content"
      "/home/carl/snapraid.content"
    ];
  };

  services.jellyfin =
    let
      configBaseDir = "/home/carl/.local/share/jellyfin";
    in
    {
      enable = true;
      openFirewall = true;
      user = "carl";
      dataDir = configBaseDir;
      logDir = "${configBaseDir}/log";
      cacheDir = "${configBaseDir}/cache";
      configDir = "${configBaseDir}/config";
    };

  services.seerr = {
    enable = true;
    openFirewall = true;
    # configDir = "/var/lib/jellyseerr/config"; # default
    # port = 5055; # default
    # **BROKEN**
    # This doesn't work because service user doesn't have write permissions to /home/carl
    # configDir = "/home/carl/.local/share/jellyseerr";
  };

  ## daily backup to obak/mrks script
  systemd.services."sync-to-offsites" = {
    script = "files --execute sync_nax_to_offsites";
    serviceConfig = {
      Type = "oneshot";
      User = "carl";
    };
    environment = rec {
      GEM_HOME = "/home/carl/.local/share/gems/nix";
      # mkForce needed to take precedence over default systemd PATH value.
      # Default PATH contains direct nix store paths to a few bin directories,
      #  like coreutils, but is missing a lot like ruby+rsync
      PATH = pkgs.lib.mkForce "/run/current-system/sw/bin:/home/carl/.local/bin";
    };
  };
  systemd.timers."sync-to-offsites" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Decodes the folder-format Signal backups (backup v2) that syncthing brings
  # over from the phone. Replaces the old signal-decode job: Signal's 8.x
  # on-device backup upgrade retired the single-file .backup format, and with it
  # the signal-decode binary that job depended on.
  systemd.services."signal-decode-v2" = {
    script = "ruby /home/carl/projects/scratch/rb/signal_v2_decode_cronjob.rb";
    serviceConfig = {
      Type = "oneshot";
      User = "carl";
    };
    environment = {
      # mkForce needed to take precedence over default systemd PATH value.
      # Needs ruby, plus file(1) to identify decrypted attachments.
      PATH = pkgs.lib.mkForce "/run/current-system/sw/bin:/home/carl/.local/bin";
    };
  };
  systemd.timers."signal-decode-v2" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
  };

  time.timeZone = "America/Chicago";

  # The release this machine was first installed with. Never change it.
  system.stateVersion = "24.05";
}
