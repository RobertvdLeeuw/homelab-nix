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
  ];

  sops.templates."syncthing" = {
    content = ''
      network={
        ssid="${config.sops.placeholder."wifi/home/ssid"}"
        psk="${config.sops.placeholder."wifi/home/psk"}"
      }
    '';
    owner = "wpa_supplicant";
    mode = "0440";
  };

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    firewall.allowedTCPPorts = [ 8384 ]; # Web GUI (if you want remote access)
  };

  services = {
    syncthing = {
      enable = true;
      user = "robert"; # Run as your user
      dataDir = "/home/robert"; # Default data location
      configDir = "/home/robert/.config/syncthing"; # Where Syncthing stores its config

      openDefaultPorts = true; # Opens 22000 TCP and 22000,21027 UDP for sync/discovery

      guiPasswordFile = config.sops.secrets."syncthing/password".path;
      settings.gui.user = "robert";
    };
  };
}
