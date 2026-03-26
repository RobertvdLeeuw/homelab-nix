{
  config,
  lib,
  pkgs,
  ...
}:

let
  hardening = import ../../hardening.nix { inherit lib; };
in
{
  services = {
    syncthing = {
      enable = true;
      user = "robert";
      dataDir = "/home/robert";
      configDir = "/home/robert/.config/syncthing";
      openDefaultPorts = true;
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

    nginx.virtualHosts."sync.rvdlserver.nl" = {
      forceSSL = true;
      useACMEHost = "rvdlserver.nl";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8384/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
    };
  };

  systemd.services.syncthing = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = hardening.hardened.standard // {
      ProtectHome = false; # Syncthing needs user files
      ReadWritePaths = [
        "/home/robert/nc"
        "/home/robert/.config/syncthing"
      ];
    };
  };
}
