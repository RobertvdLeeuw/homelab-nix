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

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;
    firewall.allowedTCPPorts = [
      8022 # SSH
      8384 # Syncthing
      8222 # Vaultwarden
    ];
  };

  sops.templates."vaultwarden.env" = {
    content = ''
      ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}
    '';
    owner = "vaultwarden";
    mode = "0400";
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
      settings = {
        gui.user = "robert";
        devices = {
          # TODO: Hide these via sops?
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
        # LAN access - using 0.0.0.0 to allow access from desktop
        ROCKET_ADDRESS = "0.0.0.0";
        ROCKET_PORT = 8222;
        ROCKET_LOG = "critical";

        # Domain will be http://nixos-homelab:8222 for LAN access
        # Update this when you set up tailscale/reverse proxy
        DOMAIN = "http://nixos-homelab:8222";

        # Disable signups - you'll create accounts via admin panel
        SIGNUPS_ALLOWED = false;

        # Disable invitations for now (can enable later)
        INVITATIONS_ALLOWED = false;

        # You can configure SMTP later if needed
        # SMTP_HOST = "127.0.0.1";
        # SMTP_PORT = 25;
        # SMTP_SSL = false;
      };
    };
  };

  systemd.services.wpa_supplicant.serviceConfig.BindReadOnlyPaths = [
    "/run/secrets/rendered/vaultwarden.env"
  ];

  systemd.services = {
    nix-daemon.serviceConfig = {
      MemoryMax = "13G";
      MemoryHigh = "10G";
    };

    syncthing.serviceConfig = hardened-standard // {
      ProtectHome = false; # Syncthing needs user files
      ReadWritePaths = [
        "/home/robert/nc"
        "/home/robert/.config/syncthing"
      ];
    };

    # vaultwarden.serviceConfig = hardened-standard // {
    #   # Vaultwarden needs to write to its data directory
    #   ReadWritePaths = [
    #     "/var/lib/vaultwarden"
    #   ];
    #
    #   # Allow binding to 0.0.0.0:8222 for LAN access
    #   RestrictAddressFamilies = [
    #     "AF_UNIX"
    #     "AF_INET"
    #     "AF_INET6"
    #   ];
    #
    #   BindReadOnlyPaths = [
    #     config.sops.templates."vaultwarden.env".path
    #   ];
    # };
  };
}
