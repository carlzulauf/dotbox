# system flake file
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nixpkgs-2605.url = "github:NixOS/nixpkgs/26.05";
    # Fork pinned to the omnissa-horizon-client tile-font fix until it lands upstream.
    # nixpkgs-omnissa.url = "github:carlzulauf/nixpkgs/fix-omnissa-horizon-client-tile-fonts";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    # hermes-agent.url = "github:NousResearch/hermes-agent";
    puma-dev.url = "github:carlzulauf/puma-dev-flake";
    ds4.url = "github:carlzulauf/ds4.nix";
    # nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    puma-dev,
    ds4,
    # hermes-agent,
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
        nixpkgs-2605 = import attrs.nixpkgs-2605 {
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
        # hermes-agent.nixosModules.default
        home-manager.nixosModules.home-manager
        ({ config, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.sharedModules = [
            # nix-openclaw.homeManagerModules.openclaw
          ];
          home-manager.extraSpecialArgs = let
            guiEnabled = config.dotbox.gui.enable;
          in {
            inherit guiEnabled;
          };
          home-manager.users.carl = ./includes/home-manager.nix;
        })
      ];
    };
    mkIso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs // {
        nixpkgs-master = import attrs.nixpkgs-master {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        nixpkgs-2605 = import attrs.nixpkgs-2605 {
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
