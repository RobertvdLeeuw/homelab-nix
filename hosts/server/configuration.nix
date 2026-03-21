{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Tier 1: Always safe - applies to everything
  hardened-base = {
    PrivateTmp = lib.mkDefault true;
    NoNewPrivileges = lib.mkDefault true;
    ProtectKernelTunables = lib.mkDefault true;
    ProtectKernelModules = lib.mkDefault true;
    ProtectKernelLogs = lib.mkDefault true;
    ProtectControlGroups = lib.mkDefault true;
    ProtectClock = lib.mkDefault true;
    ProtectHostname = lib.mkDefault true;
    LockPersonality = lib.mkDefault true;
    RestrictRealtime = lib.mkDefault true;
    RestrictSUIDSGID = lib.mkDefault true;
    RemoveIPC = lib.mkDefault true;
    SystemCallArchitectures = lib.mkDefault "native";
    PrivateDevices = lib.mkDefault true;
    RestrictNamespaces = lib.mkDefault true;
    CapabilityBoundingSet = lib.mkDefault "";
    AmbientCapabilities = lib.mkDefault "";
  };

  # Tier 2: Standard hardening - works for 80% of services
  # Use this for: web services, file sync, databases, most network daemons
  hardened-standard = hardened-base // {
    ProtectSystem = lib.mkDefault "strict";
    ProtectHome = lib.mkDefault true;
    RestrictAddressFamilies = lib.mkDefault [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    MemoryDenyWriteExecute = lib.mkDefault true;
    SystemCallFilter = lib.mkDefault [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
    SystemCallErrorNumber = lib.mkDefault "EPERM";
  };

  # Tier 3: Strict - maximum isolation for highly isolated services
  # Use for services that don't interact with host users/files
  hardened-strict = hardened-standard // {
    PrivateUsers = lib.mkDefault true; # Run in private user namespace
  };
in
{
  imports = [
    ../common-config.nix
    ./hardware-configuration.nix
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;
    firewall = {
      allowedTCPPorts = [
        8022 # SSH
        # 8384 # Syncthing
        # 8222 # Vaultwarden
      ];
      allowedUDPPorts = [ config.services.tailscale.port ];

      # Allow Tailscale traffic
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  sops.templates."vaultwarden.env" = {
    content = ''
      ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}
    '';
    owner = "vaultwarden";
    mode = "0400";
  };

  services = {
    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets."tailscale/auth-key".path;
      useRoutingFeatures = "server";
      extraUpFlags = [ "--ssh" ];
    };

    nginx = {
      enable = true;

      # Recommended settings for security and performance
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      virtualHosts = {
        # Vaultwarden
        "${config.networking.hostName}" = {
          enableACME = false;
          forceSSL = true;

          sslCertificate = "/var/lib/tailscale/certs/nixos-homelab.tail672432.ts.net.crt";
          sslCertificateKey = "/var/lib/tailscale/certs/nixos-homelab.tail672432.ts.net.key";

          locations = {
            "/vault/" = {
              proxyPass = "http://127.0.0.1:8222";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;

                proxy_read_timeout 3600;
                proxy_connect_timeout 3600;
                proxy_send_timeout 3600;
              '';
            };

            "/sync/" = {
              proxyPass = "http://127.0.0.1:8384/";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;
              '';
            };

            # "/plex/" = {
            #   proxyPass = "http://127.0.0.1:32400/";
            #   proxyWebsockets = true;
            #   extraConfig = ''
            #     # Allow long streaming sessions
            #     proxy_read_timeout 3600;
            #     proxy_connect_timeout 3600;
            #     proxy_send_timeout 3600;
            #     send_timeout 100m;
            #
            #     # Forward client info to Plex
            #     proxy_set_header X-Real-IP $remote_addr;
            #     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            #     proxy_set_header X-Forwarded-Proto $scheme;
            #     proxy_set_header X-Forwarded-Host $host;
            #     proxy_set_header Referer $server_addr;
            #     proxy_set_header Origin $server_addr;
            #
            #     # Plex-specific headers (pass through)
            #     proxy_set_header X-Plex-Client-Identifier $http_x_plex_client_identifier;
            #     proxy_set_header X-Plex-Device $http_x_plex_device;
            #     proxy_set_header X-Plex-Device-Name $http_x_plex_device_name;
            #     proxy_set_header X-Plex-Platform $http_x_plex_platform;
            #     proxy_set_header X-Plex-Platform-Version $http_x_plex_platform_version;
            #     proxy_set_header X-Plex-Product $http_x_plex_product;
            #     proxy_set_header X-Plex-Token $http_x_plex_token;
            #     proxy_set_header X-Plex-Version $http_x_plex_version;
            #
            #     # Websocket support for streaming
            #     proxy_http_version 1.1;
            #     proxy_set_header Upgrade $http_upgrade;
            #     proxy_set_header Connection "upgrade";
            #
            #     # Disable buffering for streaming
            #     proxy_redirect off;
            #     proxy_buffering off;
            #
            #     # Support large file uploads (camera uploads, etc)
            #     client_max_body_size 100M;
            #   '';
            # };

            "/adguard/" = {
              proxyPass = "http://127.0.0.1:3003/";
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
      };
    };

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

    vaultwarden = {
      enable = true;
      backupDir = "/var/local/vaultwarden/backup";
      environmentFile = config.sops.templates."vaultwarden.env".path;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        ROCKET_LOG = "critical";

        DOMAIN = "https://${config.networking.hostName}/vault";

        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = false;
      };
    };

    plex = {
      enable = true;
      openFirewall = false; # Routing through Tailscale + nginx
      dataDir = "/var/lib/plex";
      user = "robert";
    };

    adguardhome = {
      enable = true;
      host = "127.0.0.1";
      port = 3003;
      settings = {
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
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/tailscale 0711 root root - -" # For NGINX to read cerfiticates.
      "d /var/lib/plex 0755 robert users - -"
    ];

    services = {
      nix-daemon.serviceConfig = {
        MemoryMax = "13G";
        MemoryHigh = "10G";
      };

      tailscaled = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardened-base // {
          # Tailscale needs network and some privileges
          CapabilityBoundingSet = [
            "CAP_NET_ADMIN"
            "CAP_NET_RAW"
            "CAP_NET_BIND_SERVICE"
          ];
          AmbientCapabilities = [
            "CAP_NET_ADMIN"
            "CAP_NET_RAW"
            "CAP_NET_BIND_SERVICE"
          ];
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          # Tailscale needs to manage network interfaces
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateDevices = false;
          ReadWritePaths = [
            "/var/lib/tailscale"
          ];
          SystemCallFilter = [
            "@system-service"
            "@network-io"
          ];
        };
      };

      nginx = {
        after = [ "tailscale.service" ];
        wants = [ "tailscale.service" ];

        serviceConfig = hardened-standard // {
          # nginx needs to bind to privileged ports and read certs
          CapabilityBoundingSet = [
            "CAP_NET_BIND_SERVICE"
            "CAP_SYS_RESOURCE"
          ];

          AmbientCapabilities = [
            "CAP_NET_BIND_SERVICE"
            "CAP_SYS_RESOURCE"
          ];

          ReadWritePaths = [
            "/var/log/nginx"
            "/var/cache/nginx"
          ];
        };
      };

      syncthing = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardened-standard // {
          ProtectHome = false; # Syncthing needs user files
          ReadWritePaths = [
            "/home/robert/nc"
            "/home/robert/.config/syncthing"
          ];
        };
      };

      vaultwarden = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardened-standard // {
          # Vaultwarden needs to write to its data directory
          ReadWritePaths = [
            "/var/lib/vaultwarden"
            "/var/local/vaultwarden"
          ];
        };
      };

      plex = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardened-standard // {
          ReadWritePaths = [
            "/var/lib/plex"
            "/home/robert/media"
          ];

          # Plex uses bubblewrap, needs user namespaces and no capability restrictions
          RestrictNamespaces = false;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
        };
      };

      adguardhome = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardened-standard // {
          # Needs to bind to port 53 (privileged)
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];

          ReadWritePaths = [
            "/var/lib/AdGuardHome"
          ];
        };
      };
    };
  };
}
