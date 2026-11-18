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
  # users = {
  #   users.adguardhome = {
  #     isSystemUser = true;
  #     group = "adguardhome";
  #     extraGroups = [ "nginx" ];
  #   };
  #   groups.adguardhome = { };
  # };

  sops.secrets = {
    "adguard/username" = { };
    "adguard/password_hash" = { };
  };

  services = {
    adguardhome = {
      enable = true;
      host = "127.0.0.1";
      port = 3003;
      mutableSettings = false; # No setting changes via UI.
      settings = {
        users = [
          {
            name = config.sops.placeholder."adguard/username";
            password = config.sops.placeholder."adguard/password_hash";
          }
        ];
        dns = {
          bind_hosts = [ facts.hosts.server.tailscale ];
          port = 53;
          bootstrap_dns = [
            "1.1.1.1"
            "1.0.0.1"
          ];
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
              domain = "*.nixos-homelab.${facts.tailnet}";
              answer = facts.hosts.server.tailscale;
              enabled = true;
            }
            {
              domain = "*.nixos-homelab";
              answer = facts.hosts.server.tailscale;
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

    nginx.virtualHosts."adguard.${facts.domain}" = {
      forceSSL = true;
      useACMEHost = facts.domain;

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

    # Can't pass a file for credentials, so this is how we get sops stuff into config.
    preStart = lib.mkAfter ''
      f="$STATE_DIRECTORY/AdGuardHome.yaml"
      ${pkgs.replace-secret}/bin/replace-secret '${
        config.sops.placeholder."adguard/username"
      }' "$CREDENTIALS_DIRECTORY/user" "$f"
      ${pkgs.replace-secret}/bin/replace-secret '${
        config.sops.placeholder."adguard/password_hash"
      }' "$CREDENTIALS_DIRECTORY/hash" "$f"
    '';

    serviceConfig = common-tools.hardening.base // {
      # AdGuard needs to bind to port 53 and write to its config/data
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      ReadWritePaths = [
        "/var/lib/AdGuardHome"
      ];
      LoadCredential = [
        "user:${config.sops.secrets."adguard/username".path}"
        "hash:${config.sops.secrets."adguard/password_hash".path}"
      ];
      # BindReadOnlyPaths = [
      #   "/var/lib/acme/rvdlserver.nl/cert.pem"
      #   "/var/lib/acme/rvdlserver.nl/key.pem"
      # ];
    };
  };

  # networking.firewall.allowedTCPPorts = [ 443 ];
}
