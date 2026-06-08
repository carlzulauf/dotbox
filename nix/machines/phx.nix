{ config, pkgs, nixos-hardware, ... }:

{
  # GPD Win Max 2 w/7840u
  networking.hostName = "phx";

  imports =
    [
      # DISABLED 3/26/2025 - preventing kernel from building
      # nixos-hardware.nixosModules.common-cpu-amd-zenpower

      # these become superfluous when gpd profile is enabled:
      # nixos-hardware.nixosModules.common-cpu-amd-pstate
      # nixos-hardware.nixosModules.common-cpu-amd
      # nixos-hardware.nixosModules.common-gpu-amd
      nixos-hardware.nixosModules.gpd-win-max-2-2023

      ../includes/gui.nix
      ../includes/gnome.nix
      ../includes/gaming.nix
      ../includes/dev.nix
      ../includes/printing.nix
    ];

  hardware.gpd.ppt = {
    adapter = { # plugged in
      fast-limit  = 28000; # was 35000
      slow-limit  = 26000; # was 32000
      stapm-limit = 22000; # was 28000
    };
    battery = {
      fast-limit  = 24000; # was 35000
      slow-limit  = 22000; # was 32000
      stapm-limit = 18000; # was 28000
    };
  };

  # ENABLE COSMIC DESKTOP
  # services.desktopManager.cosmic.enable = true;
  # services.displayManager.cosmic-greeter.enable = true;
  # /COSMIC

  fileSystems."/mnt/buttress" = {
    device = "/dev/disk/by-uuid/216e8bf5-a4f4-415e-9beb-e96e266d11d5";
    fsType = "ext4";
  };

  # bleeding edge kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Workaround for SuspendThenHibernate: https://lore.kernel.org/linux-kernel/20231106162310.85711-1-mario.limonciello@amd.com/
  # Copied from https://github.com/NixOS/nixos-hardware/blob/master/framework/13-inch/common/amd.nix
  # boot.kernelParams = [
  #   "rtc_cmos.use_acpi_alarm=1"
  #   # There seems to be an issue with panel self-refresh (PSR) that
  #   # causes hangs for users.
  #   #
  #   # https://community.frame.work/t/fedora-kde-becomes-suddenly-slow/58459
  #   # https://gitlab.freedesktop.org/drm/amd/-/issues/3647
  #   "amdgpu.dcdebugmask=0x10"
  # ];

  # found windows drive via `map -c` and trying to run `X:\EFI\Microsoft\Boot\Bootmgfw.efi`
  boot.loader.systemd-boot.windows = {
    wm2 = {
      title = "Windows 11";
      efiDeviceHandle = "HD1b";
    };
  };

  environment.systemPackages = with pkgs; [ wavemon ];

  # Make the lid just lock, not suspend. I'll have to enter suspend manually.
  services.logind.lidSwitch = "lock";
  services.fwupd.enable = true;

  services.ollama = {
    # package = nixpkgs-stable.legacyPackages.x86_64-linux.ollama;
    acceleration = "rocm";
    enable = true;
    host = "0.0.0.0";
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 4141; # AI! AI!
    openFirewall = true;
  };

  time.timeZone = "America/Chicago";
}
