{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common-config.nix
    ./hardware-configuration.nix
    ./modules/network.nix
    ./modules/vaultwarden.nix
    ./modules/syncthing.nix
    ./modules/adguard.nix
    ./modules/homepage.nix
    ./modules/degoog.nix
    ./modules/topology.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;

    firewall.allowedTCPPorts = [
      8022 # SSH
    ];
  };

  systemd.services.nix-daemon.serviceConfig = {
    MemoryMax = "13G";
    MemoryHigh = "10G";
  };
}
