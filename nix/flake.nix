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

    # gem some LLM tools from this repo instead
    llm-agents.url = "github:numtide/llm-agents.nix";

    # reverse proxy that sets up per app subdomains on
    #  port 80/443 with SSL for locally running apps (ie: dev)
    puma-dev.url = "github:carlzulauf/puma-dev-flake";

    # Nix flake for DwarfStar, model runner for DeepSeek V4 Flash/Pro
    ds4.url = "github:carlzulauf/ds4.nix";
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
    activeHosts = [
      "generic" # Base host for initial installs (no hardware-specific config)
      "frix" # Framework Desktop
      "enix" # HP Envy Laptop
      "khoa" # torrent station
      "nax"  # NAS
      "nixd" # Custom Desktop
      "obak" # Offsite Backup
      "phx"  # GPD WinMax
      "xps"  # Work XPS
      "xtv"  # TV Gaming
    ];
    mkHost = host: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs // {
        nixpkgs-master = import attrs.nixpkgs-master {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        llm-agents = attrs.llm-agents.packages.x86_64-linux;
      };
      modules = [
        ./configuration.nix
        ./includes/defaults.nix
        ./includes/carl.nix
        ./machines/${host}.nix
        puma-dev.nixosModules.puma-dev
        ds4.nixosModules.ds4
      ];
    };
    mkIso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs // {
        nixpkgs-master = import attrs.nixpkgs-master {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
      modules = [ ./iso.nix ];
    };
  in
  {
    nixosConfigurations = nixpkgs.lib.genAttrs activeHosts mkHost // {
      iso = mkIso;
    };
  };
}
