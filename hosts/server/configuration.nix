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

    # Base
    ./modules/network.nix
    ./modules/acme.nix
    ./modules/cloudflared.nix

    # Internal Services
    ./modules/vaultwarden.nix
    ./modules/syncthing.nix
    ./modules/dns.nix
    ./modules/homepage.nix
    ./modules/calendar.nix

    # Uncucking
    ./modules/search-engine.nix
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
