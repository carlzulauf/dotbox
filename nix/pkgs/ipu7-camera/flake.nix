{
  description = "Intel IPU7 Camera Support — vision-drivers kernel module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    visionDrivers = nixpkgs.callPackage ./default.nix {
      kernel = nixpkgs.linuxPackages_latest.kernel;
      kernelModuleMakeFlags = nixpkgs.linuxPackages_latest.kernelModuleMakeFlags;
    };
  in {
    packages.x86_64-linux.vision-drivers = visionDrivers;

    nixosModules.vision-drivers = { pkgs, lib, config, ... }:
      let
        drv = pkgs.callPackage ./default.nix {
          kernel = pkgs.linuxPackages_latest.kernel;
          kernelModuleMakeFlags = pkgs.linuxPackages_latest.kernelModuleMakeFlags;
        };
      in {
        boot.kernelModules = [ "intel_cvs" ];
        boot.extraModulePackages = [ drv ];
      };
  };
}
