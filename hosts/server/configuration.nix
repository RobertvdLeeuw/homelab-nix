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

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    firewall.allowedTCPPorts = [
      8384
      8022
    ]; # Web GUI (if you want remote access)
  };

  services = {
    syncthing = {
      enable = true;
      user = "robert"; # Run as your user
      dataDir = "/home/robert"; # Default data location
      configDir = "/home/robert/.config/syncthing"; # Where Syncthing stores its config

      openDefaultPorts = true; # Opens 22000 TCP and 22000,21027 UDP for sync/discovery

      guiPasswordFile = config.sops.secrets."syncthing/password".path;
      guiAddress = "0.0.0.0:8384";

      settings = {
        gui.user = "robert";
        devices = {
          "desktop".id = "24PKA7Z-UWYQM46-UORQCZS-TKM3Z3F-YP2CL7Z-A5PTLI5-6EH5OKX-HZLMQAV";
          "laptop".id = "J267XXP-JPQEOP7-D23EIG5-QU25QS2-Y2KLCBT-NSLSG4A-UWDAU5X-54S4UAV";
        };

        folders = {
          "nc-storage" = {
            path = "/home/robert/nc";
            devices = [
              "desktop"
              "laptop"
            ];
            ignorePerms = false;
          };
        };
      };
    };
  };
}
