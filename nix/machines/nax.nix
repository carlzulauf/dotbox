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
      nixos-hardware.nixosModules.common-cpu-amd-zenpower
      nixos-hardware.nixosModules.common-gpu-amd
      ../includes/ai.nix
      ../includes/gui.nix
      ../includes/tv.nix
    ];

  environment.systemPackages = with pkgs; [
    nvtopPackages.amd
  ];

  # nix.settings.substituters = [ "http://nax/" ];

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

  systemd.services."signal-decode" = {
    script = "ruby /home/carl/projects/scratch/rb/signal_decode_cronjob.rb";
    serviceConfig = {
      Type = "oneshot";
      User = "carl";
    };
    environment = {
      GEM_HOME = "/home/carl/.local/share/gems/nix";
      PATH = pkgs.lib.mkForce "/run/current-system/sw/bin:/home/carl/.local/bin";
    };
  };
  systemd.timers."signal-decode" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };
  };

  #services.nginx = {
  #  enable = true;
  #  appendHttpConfig = ''
  #    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=cachecache:100m max_size=100g inactive=365d use_temp_path=off;

  #    # Cache only success status codes; in particular we don't want to cache 404s.
  #    # See https://serverfault.com/a/690258/128321
  #    map $status $cache_header {
  #      200     "public";
  #      302     "public";
  #      default "no-cache";
  #    }
  #    access_log /var/log/nginx/access.log;
  #  '';

  #  virtualHosts."nax" = {
  #    locations."/" = {
  #      root = "/var/public-nix-cache";
  #      extraConfig = ''
  #        expires max;
  #        add_header Cache-Control $cache_header always;
  #        # Ask the upstream server if a file isn't available locally
  #        error_page 404 = @fallback;
  #      '';
  #    };

  #    extraConfig = ''
  #      # Using a variable for the upstream endpoint to ensure that it is
  #      # resolved at runtime as opposed to once when the config file is loaded
  #      # and then cached forever (we don't want that):
  #      # see https://tenzer.dk/nginx-with-dynamic-upstreams/
  #      # This fixes errors like
  #      #   nginx: [emerg] host not found in upstream "upstream.example.com"
  #      # when the upstream host is not reachable for a short time when
  #      # nginx is started.
  #      resolver 8.8.8.8;
  #      set $upstream_endpoint http://cache.nixos.org;
  #    '';

  #    locations."@fallback" = {
  #      proxyPass = "$upstream_endpoint";
  #      extraConfig = ''
  #        proxy_cache cachecache;
  #        proxy_cache_valid  200 302  60d;
  #        expires max;
  #        add_header Cache-Control $cache_header always;
  #      '';
  #    };

  #    # We always want to copy cache.nixos.org's nix-cache-info file,
  #    # and ignore our own, because `nix-push` by default generates one
  #    # without `Priority` field, and thus that file by default has priority
  #    # 50 (compared to cache.nixos.org's `Priority: 40`), which will make
  #    # download clients prefer `cache.nixos.org` over our binary cache.
  #    locations."= /nix-cache-info" = {
  #      # Note: This is duplicated with the `@fallback` above,
  #      # would be nicer if we could redirect to the @fallback instead.
  #      proxyPass = "$upstream_endpoint";
  #      extraConfig = ''
  #        proxy_cache cachecache;
  #        proxy_cache_valid  200 302  60d;
  #        expires max;
  #        add_header Cache-Control $cache_header always;
  #      '';
  #    };
  #  };
  #};

  time.timeZone = "America/Chicago";
}
