{
  config,
  lib,
  pkgs,
  ...
}:

let
  hardened-base = {
    PrivateTmp = true; # Isolate /tmp and /var/tmp
    NoNewPrivileges = true; # Prevent privilege escalation
    ProtectKernelTunables = true; # Protect /proc/sys, /sys
    ProtectKernelModules = true; # Prevent loading kernel modules
    ProtectKernelLogs = true; # Restrict access to kernel logs
    ProtectControlGroups = true; # Make cgroup filesystem read-only
    ProtectClock = true; # Prevent setting system clock
    ProtectHostname = true; # Prevent changing hostname
    LockPersonality = true; # Prevent personality changes
    RestrictRealtime = true; # Prevent realtime scheduling (unless audio/video)
    RestrictSUIDSGID = true; # Prevent SUID/SGID file creation
    RemoveIPC = true; # Clean up IPC objects on shutdown
    SystemCallArchitectures = "native"; # Only allow native architecture

    PrivateDevices = true; # No access to physical devices (remove if service needs /dev/*)
    RestrictNamespaces = true; # Prevent namespace creation (remove for Docker/containers)
    CapabilityBoundingSet = ""; # Drop all capabilities (add back specific ones as needed)
    AmbientCapabilities = ""; # No ambient capabilities
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

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    firewall.allowedTCPPorts = [
      8384
      8022
    ]; # Web GUI (if you want remote access)
  };

  systemd.services.nix-daemon.serviceConfig = {
    MemoryMax = "13G";
    MemoryHigh = "10G";
  };

  services = {
    syncthing = {
      enable = true;
      user = "robert"; # Run as your user
      dataDir = "/home/robert"; # Default data location
      configDir = "/home/robert/.config/syncthing"; # Where Syncthing stores its config

      openDefaultPorts = true; # Opens 22000 TCP and 22000,21027 UDP for sync/discovery

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
  };

  systemd.services.syncthing.serviceConfig = hardened-base;
}
