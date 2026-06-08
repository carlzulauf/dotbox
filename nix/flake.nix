# system flake file
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    # pinned for frix: 7.0.8 regresses MT7925 bluetooth (wmt func ctrl -22)
    nixpkgs-linux-7_0_5.url = "github:NixOS/nixpkgs/c6e5ca3c836a5f4dd9af9f2c1fc1c38f0fac988a";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    # hermes-agent.url = "github:NousResearch/hermes-agent";
    puma-dev.url = "github:carlzulauf/puma-dev-flake";
    # nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    puma-dev,
    # hermes-agent,
    ...
  }@attrs:
  let
    activeHosts = [
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
        nixpkgs-linux-7_0_5 = import attrs.nixpkgs-linux-7_0_5 {
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
        # hermes-agent.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.sharedModules = [
            # nix-openclaw.homeManagerModules.openclaw
          ];
          home-manager.users.carl = ./includes/home.nix;
        }
      ];
    };
  in
  {
    nixosConfigurations = nixpkgs.lib.genAttrs activeHosts mkHost;
  };
}
