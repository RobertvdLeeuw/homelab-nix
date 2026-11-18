{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:

let
  common-tools = import ../../common-tools.nix { inherit lib; };
  facts = inputs.dotfiles.lib.facts;
in
{
  sops.secrets = {
    "syncthing/password" = { };
    "syncthing/cert" = { };
    "syncthing/key" = { };
  };

  services = {
    syncthing = {
      enable = true;

      user = "robert";
      dataDir = "/home/robert";
      configDir = "/home/robert/.config/syncthing";

      openDefaultPorts = true;

      guiPasswordFile = config.sops.secrets."syncthing/password".path;
      guiAddress = "0.0.0.0:8384";

      cert = config.sops.secrets."syncthing/cert".path;
      key = config.sops.secrets."syncthing/key".path;

      settings = {
        gui.user = "robert";
        devices = lib.mapAttrs (_: id: { inherit id; }) facts.syncthing.devices;
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

    nginx.virtualHosts."sync.${facts.domain}" = {
      forceSSL = true;
      useACMEHost = facts.domain;

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

    serviceConfig = common-tools.hardening.standard // {
      ProtectHome = false; # Syncthing needs user files
      ReadWritePaths = [
        "/home/robert/nc"
        "/home/robert/.config/syncthing"
      ];
    };
  };
}
