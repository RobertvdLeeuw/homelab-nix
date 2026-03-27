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
  sops.templates."radicale-htpasswd" = {
    content = ''
      robert:${config.sops.placeholder."radicale/htpasswd"}
    '';
    owner = "radicale";
    mode = "0400";
  };

  users.users.radicale.extraGroups = [ "nginx" ];

  services = {
    radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "127.0.0.1:5232" ];
          ssl = true;
          certificate = "/var/lib/acme/rvdlserver.nl/cert.pem";
          key = "/var/lib/acme/rvdlserver.nl/key.pem";
        };

        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.templates."radicale-htpasswd".path;
          htpasswd_encryption = "bcrypt";
        };

        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
        };

        logging = {
          level = "info";
        };
      };
    };

    nginx.virtualHosts."cal.rvdlserver.nl" = {
      forceSSL = true;
      useACMEHost = "rvdlserver.nl";

      locations."/" = {
        proxyPass = "https://127.0.0.1:5232";
        extraConfig = ''
          proxy_ssl_verify off;
          proxy_set_header X-Script-Name /;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;
          proxy_pass_header Authorization;
        '';
      };
    };
  };

  systemd.services.radicale = {
    after = [
      "network-online.target"
      "acme-rvdlserver.nl.service"
    ];
    wants = [
      "network-online.target"
      "acme-rvdlserver.nl.service"
    ];

    serviceConfig = hardening.hardened.standard // {
      ReadWritePaths = [ "/var/lib/radicale" ];
      BindReadOnlyPaths = [
        config.sops.templates."radicale-htpasswd".path
        "/var/lib/acme/rvdlserver.nl/cert.pem"
        "/var/lib/acme/rvdlserver.nl/key.pem"
      ];
    };
  };
}
