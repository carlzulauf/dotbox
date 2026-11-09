# system flake file
{
  inputs = {
    # primary channel
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # used to keep a few tools on the bleeding edge, and
    #  as an escape hatch when an unstable pkg is broken
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";

    # used for better per-machine hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    # reverse proxy that sets up per app subdomains on
    #  port 80/443 with SSL for locally running apps (ie: dev)
    puma-dev.url = "github:carlzulauf/puma-dev-flake";
    puma-dev.inputs.nixpkgs.follows = "nixpkgs";
    puma-dev.inputs.flake-utils.follows = "ds4/flake-utils";

    # Nix flake for DwarfStar, model runner for DeepSeek V4 Flash/Pro
    ds4.url = "github:carlzulauf/ds4.nix";
    ds4.inputs.nixpkgs.follows = "nixpkgs";

    # Voxtype: local speech-to-text dictation (see includes/dictation.nix).
    #  nixpkgs packages it too, but without the ONNX engines (Cohere, Parakeet)
    voxtype.url = "github:peteonrails/voxtype";
    voxtype.inputs.nixpkgs.follows = "nixpkgs";
    voxtype.inputs.flake-utils.follows = "ds4/flake-utils";

    # AI coding agents (claude-code, pi, claude-desktop, ...), updated daily.
    #  No nixpkgs follows, so builds come from cache.numtide.com (see configuration.nix)
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    puma-dev,
    ds4,
    ...
  }@attrs:
  let
    specialArgs = attrs // {
      nixpkgs-master = import attrs.nixpkgs-master {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    };
    activeHosts = [
      "generic" # Base host for initial installs (no hardware-specific config)
      "frix" # Framework Desktop
      "enix" # HP Envy Laptop
      "khoa" # torrent station
      "nax"  # NAS
      "nixd" # Custom Desktop
      "nirvm" # niri VM (libvirt guest, see bin/nirvm)
      "obak" # Offsite Backup
      "phx"  # GPD WinMax
      "xps"  # Work XPS
      "xtv"  # TV Gaming
    ];
    # Each machine's hardware-configuration.nix, checked in under hardware/ by
    # bin/install_nix. Hosts not checked in yet, and generic, use the one
    # generated in /etc/nixos.
    hardwareConfig = host:
      if builtins.pathExists ./hardware/${host}.nix
      then ./hardware/${host}.nix
      else ./hardware-configuration.nix;
    # Public cert of each machine's puma-dev CA, generated in ~/.puma-dev-ssl
    # and checked in under puma-dev/ by bin/install_nix. The key stays on the
    # machine. builtins.path stores the cert on its own, so changes elsewhere in
    # the repo don't rebuild the CA bundle or restart puma-dev.
    pumaDevCa = host: {
      services.puma-dev.caCertificate =
        if builtins.pathExists ./puma-dev/${host}.pem
        then builtins.path { path = ./puma-dev/${host}.pem; name = "puma-dev-ca-${host}.pem"; }
        else null;
    };
    mkHost = host: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit specialArgs;
      modules = [
        (hardwareConfig host)
        ./configuration.nix
        ./includes/defaults.nix
        ./includes/carl.nix
        ./machines/${host}.nix
        puma-dev.nixosModules.puma-dev
        (pumaDevCa host)
        ds4.nixosModules.ds4
      ];
    };
    mkIso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit specialArgs;
      modules = [ ./iso.nix ];
    };
  in
  {
    nixosConfigurations = nixpkgs.lib.genAttrs activeHosts mkHost // {
      iso = mkIso;
    };
  };
}
