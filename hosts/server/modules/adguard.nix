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

    nginx.virtualHosts."${config.networking.hostName}".locations = {
      "/adguard" = {
        return = "301 /adguard/";
      };
      "/adguard/" = {
        proxyPass = "http://127.0.0.1:3003/";
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Prefix /adguard;

          proxy_redirect / /adguard/;
          proxy_redirect ~^/(.*)$ /adguard/$1;
        '';
      };
    };
  };

  systemd.services.adguardhome = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = hardening.hardened.base // {
      # AdGuard needs to bind to port 53 and write to its config/data
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      ReadWritePaths = [
        "/var/lib/AdGuardHome"
      ];
    };
  };
}
