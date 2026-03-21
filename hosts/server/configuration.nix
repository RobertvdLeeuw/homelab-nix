{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Tier 1: Always safe - applies to everything
  hardened-base = {
    PrivateTmp = true;
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    LockPersonality = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    RemoveIPC = true;
    SystemCallArchitectures = "native";
    PrivateDevices = true;
    RestrictNamespaces = true;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
  };

  # Tier 2: Standard hardening - works for 80% of services
  # Use this for: web services, file sync, databases, most network daemons
  hardened-standard = hardened-base // {
    ProtectSystem = "strict";
    ProtectHome = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    MemoryDenyWriteExecute = true;
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
    SystemCallErrorNumber = "EPERM";
  };

  # Tier 3: Strict - maximum isolation for highly isolated services
  # Use for services that don't interact with host users/files
  hardened-strict = hardened-standard // {
    PrivateUsers = true; # Run in private user namespace
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
      # Enable Tailscale SSH (optional but recommended)
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

        # You can configure SMTP later if needed
        # SMTP_HOST = "127.0.0.1";
        # SMTP_PORT = 25;
        # SMTP_SSL = false;
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/tailscale 0711 root root - -"
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
    };
  };
}
