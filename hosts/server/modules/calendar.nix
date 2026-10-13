{
  config,
  lib,
  pkgs,
  ...
}:

let
  common-tools = import ../../common-tools.nix { inherit lib; };
in
{
  sops = {
    secrets."radicale/htpasswd" = { };

    templates."radicale-htpasswd" = {
      content = ''
        robert:${config.sops.placeholder."radicale/htpasswd"}
      '';
      owner = "radicale";
      mode = "0400";
    };
  };

  services = {
    radicale = {
      enable = true;
      settings = {
        server = {
          hosts = [ "127.0.0.1:5232" ];
          # No SSL stuff since we're inside Tailscale
        };

        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.templates."radicale-htpasswd".path;
          htpasswd_encryption = "bcrypt";
        };

        storage.filesystem_folder = "/var/lib/radicale/collections";
        logging.level = "info";
      };
    };

    nginx.virtualHosts."cal.rvdlserver.nl" = {
      forceSSL = true;
      useACMEHost = "rvdlserver.nl";

      locations."/" = {
        proxyPass = "https://127.0.0.1:5232";
        extraConfig = ''
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
    ];
    wants = [
      "network-online.target"
    ];

    serviceConfig = common-tools.hardening.standard // {
      ReadWritePaths = [ "/var/lib/radicale" ];
      BindReadOnlyPaths = [
        config.sops.templates."radicale-htpasswd".path
        "/var/lib/acme/rvdlserver.nl/cert.pem"
        "/var/lib/acme/rvdlserver.nl/key.pem"
      ];
    };
  };
}
