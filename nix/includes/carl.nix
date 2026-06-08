# For systems that should have the `carl` user set up
{ config, pkgs, ... }:

{
  # Allow 'carl' to run nmap with sudo without a password
  security.sudo.extraRules = [
    {
      users = [ "carl" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nmap";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.carl = {
    isNormalUser = true;
    description = "Carl Zulauf";
    extraGroups = [ "networkmanager" "video" "wheel" "docker" "libvirtd" ];
    packages = with pkgs; [
      # maybe add some user specific pkgs
    ];
    shell = pkgs.fish;
    linger = true;
  };

  # Setup syncthing as service for 'carl'
  services.syncthing = {
    enable = true;
    user = "carl";
    dataDir = "/home/carl";
    guiAddress = "0.0.0.0:8384";
  };
}
