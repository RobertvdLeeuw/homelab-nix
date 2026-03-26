{
  config,
  lib,
  pkgs,
  ...
}:

let
  hardening = import ../../hardening.nix { inherit lib; };

  #   stats:
  #   cpu
  #   ram
  #   storage
  #
  #   network:
  #     Up/down
  #     DNS status (adguard)
  #
  # Pages (rename):
  #   omnisearch
  #   indivuous
  #   smth email?
  #
  # services:
  #   Adguard
  #   Syncthing
  #   Jellyfin
  #   Tailscale?
  #   ...
in
{
  sops.templates."homepage-env" = {
    content = ''
      HOMEPAGE_VAR_ADGUARD_PASSWORD=${config.sops.placeholder."adguard/password"}
    '';
    # owner = "homepage-dashboard";
  };

  services = {
    homepage-dashboard = {
      enable = true;
      listenPort = 3001;

      settings = {
        title = "Homelab";
        theme = "dark";
        color = "slate";

        environmentFile =
          let
            file = pkgs.writeText "homepage-dashboard-env" ''
              LOG_LEVEL=debug
            '';
          in
          "${file}";

        layout = [
          {
            "Browsing" = {
              style = "column";
            };
          }
          {
            "Services" = {
              style = "column";
              columns = 2;
            };
          }
        ];
      };

      services = [
        {
          "Services" = [
            {
              "Vaultwarden" = {
                icon = "vaultwarden.svg";
                href = "https://${config.networking.hostName}/vault";
                description = "Password manager";
                target = "_self";
              };
            }
            {
              "Syncthing" = {
                icon = "syncthing.svg";
                href = "https://${config.networking.hostName}/sync";
                description = "File synchronization";
                target = "_self";
              };
            }
            {
              "AdGuard Home" = {
                icon = "adguard-home.svg";
                href = "https://${config.networking.hostName}/adguard";
                description = "DNS ad blocking";
                target = "_self";
              };
            }
          ];
          "Browsing" = [

          ];
        }
      ];

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
      ];
    };

    nginx.virtualHosts."${config.networking.hostName}".locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:3001";
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

  systemd.services.homepage-dashboard = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HOMEPAGE_ALLOWED_HOSTS = lib.mkForce config.networking.hostName;
    };

    serviceConfig = hardening.hardened.standard // {
      MemoryDenyWriteExecute = false; # Node.js needs JIT

      # Homepage needs to write to its config directory
      ReadWritePaths = [
        "/var/lib/private/homepage-dashboard"
      ];
    };
  };
}
