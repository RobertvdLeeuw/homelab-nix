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
  # users = {
  #   users.adguardhome = {
  #     isSystemUser = true;
  #     group = "adguardhome";
  #     extraGroups = [ "nginx" ];
  #   };
  #   groups.adguardhome = { };
  # };

  services = {
    adguardhome = {
      enable = true;
      host = "127.0.0.1";
      port = 3003;
      settings = {
        users = [
          {
            name = "admin";
            password = "$2a$12$x6UeskNnFFu6ynQy/I6H5.FPky6KkzXQKnFA/ZuTVjZPa5qSdrsiS";
          }
        ];
        dns = {
          bind_hosts = [ "100.79.157.102" ];
          port = 53;
          upstream_dns = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
        # TODO: Look into sweep-all config to have DoH on all tailscale devices.
        # tls = {
        #   enabled = true;
        #   server_name = "dns.rvdlserver.nl";
        #   force_https = false; # NGINX handles this.
        #   port_https = 443;
        #   certificate_chain = "/var/lib/acme/rvdlserver.nl/cert.pem";
        #   private_key = "/var/lib/acme/rvdlserver.nl/key.pem";
        # };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          parental_enabled = false;
          safe_search.enabled = false;

          rewrites = [
            {
              domain = "*.nixos-homelab.tail672432.ts.net";
              answer = "100.79.157.102"; # Your server's Tailscale IP
              enabled = true;
            }
            {
              domain = "*.nixos-homelab";
              answer = "100.79.157.102";
              enabled = true;
            }
          ];
        };
        filters =
          map
            (url: {
              enabled = true;
              inherit url;
            })
            [
              # Malware/hacked sites
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt"

              # Malicious URLs
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt"

              # AdGuard DNS filter (ads + trackers)
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"

              # Tracking Protection
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_3.txt"

              # Steven Black's Unified (popular all-in-one)
              "https://adguardteam.github.io/HostlistsRegistry/assets/filter_33.txt"
            ];
      };
    };

    nginx.virtualHosts."adguard.rvdlserver.nl" = {
      forceSSL = true;
      useACMEHost = "rvdlserver.nl";

      locations."/" = {
        proxyPass = "http://127.0.0.1:3003/";
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Prefix /adguard;
        '';
      };
    };
  };

  systemd.services.adguardhome = {
    after = [
      "network-online.target"
      # "acme-rvdlserver.nl.service"
    ];
    wants = [
      "network-online.target"
      # "acme-rvdlserver.nl.service"
    ];

    serviceConfig = hardening.hardened.base // {
      # AdGuard needs to bind to port 53 and write to its config/data
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      ReadWritePaths = [
        "/var/lib/AdGuardHome"
      ];
      # BindReadOnlyPaths = [
      #   "/var/lib/acme/rvdlserver.nl/cert.pem"
      #   "/var/lib/acme/rvdlserver.nl/key.pem"
      # ];
    };
  };

  # networking.firewall.allowedTCPPorts = [ 443 ];
}
