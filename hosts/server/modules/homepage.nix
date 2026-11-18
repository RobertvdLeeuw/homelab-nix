{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  common-tools = import ../../common-tools.nix { inherit lib; };
  facts = inputs.dotfiles.lib.facts;
in
{
  sops.templates."homepage-env" = {
    content = ''
      HOMEPAGE_VAR_ADGUARD_PASSWORD=${config.sops.placeholder."adguard/password_hash"}
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

        layout = [
          {
            "Uncucked Browsing" = {
              style = "column";
              columns = 1;
            };
          }
          {
            "Internal Services" = {
              style = "column";
              columns = 2;
            };
          }
        ];
      };

      services = [
        {
          "Uncucked Browsing" = [
            {
              "Search" = {
                icon = "google.svg";
                href = "https://search.${facts.domain}";
                description = "Search engine aggegrator";
                target = "_self";
              };
            }
          ];
        }
        {
          "Internal Services" = [
            {
              "Vaultwarden" = {
                icon = "vaultwarden.svg";
                href = "https://vault.${facts.domain}";
                description = "Password manager";
                target = "_self";
              };
            }
            {
              "Syncthing" = {
                icon = "syncthing.svg";
                href = "https://sync.${facts.domain}";
                description = "File synchronization";
                target = "_self";
              };
            }
            {
              "AdGuard Home" = {
                icon = "adguard-home.svg";
                href = "https://adguard.${facts.domain}";
                description = "DNS ad blocking";
                target = "_self";
              };
            }
            {
              "Radicale" = {
                icon = "radicale.svg";
                href = "https://cal.${facts.domain}";
                description = "Calendar sync";
                target = "_self";
              };
            }
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

    nginx.virtualHosts.${facts.domain} = {
      forceSSL = true;
      useACMEHost = facts.domain;

      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
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
      # HOMEPAGE_ALLOWED_HOSTS = lib.mkForce config.networking.hostName;
      HOMEPAGE_ALLOWED_HOSTS = lib.mkForce facts.domain;
      HOMEPAGE_PUBLIC_URL = facts.domain;
    };

    serviceConfig = common-tools.hardening.standard // {
      MemoryDenyWriteExecute = false; # Node.js needs JIT

      # Homepage needs to write to its config directory
      ReadWritePaths = [
        "/var/lib/private/homepage-dashboard"
      ];
    };
  };
}
