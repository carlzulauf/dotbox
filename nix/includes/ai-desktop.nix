{ config, pkgs, llm-agents, nixpkgs-master, ... }:

{
  environment.systemPackages = [
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
    (pkgs.callPackage ../pkgs/t3code-desktop { })

    # herdr-desktop finds its own herdr-core in the store. Don't add herdr-core
    #  here: found in sw/bin, the app puts sw/bin ahead of /run/wrappers/bin in
    #  every pane's PATH, breaking sudo (herdrdev/herdr-app#671)
    nixpkgs-master.herdr
    # cargo-setup-hook now has zstd-sys use the system libzstd, which nixpkgs
    #  doesn't declare for herdr-desktop
    (nixpkgs-master.herdr-desktop.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ nixpkgs-master.zstd ];
    }))
  ];
}
