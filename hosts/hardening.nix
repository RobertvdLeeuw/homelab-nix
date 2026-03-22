{ lib }:

{
  hardened = rec {
    # Tier 1: Always safe - applies to everything
    base = {
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
    standard = base // {
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
    strict = standard // {
      PrivateUsers = lib.mkDefault true; # Run in private user namespace
    };
  };
}
