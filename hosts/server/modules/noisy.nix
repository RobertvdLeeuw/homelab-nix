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
  virtualisation.oci-containers = {
    backend = "podman";
    containers.noisy = {
      image = "madereddy/noisy:latest";
      cmd = [
        "--threads"
        "3"
        "--min_sleep"
        "10.0"
        "--max_sleep"
        "25.0"
        "--log"
        "warning"
      ];
      extraOptions = [
        # Security: Drop all capabilities (noisy needs none)
        "--cap-drop=ALL"

        # Security: No new privileges (prevents privilege escalation)
        "--security-opt=no-new-privileges"

        # Filesystem: Read-only root (noisy writes nothing to disk)
        "--read-only"

        # Filesystem: Writable /tmp for Python cache/temp files
        "--tmpfs=/tmp:rw,noexec,nosuid,size=100m"

        # User: Run as non-root (Python doesn't need root)
        "--user=65534:65534" # nobody:nogroup

        # Resources: Limit to prevent runaway crawler
        "--memory=256m" # 256MB RAM limit
        "--memory-swap=256m" # No swap beyond RAM limit
        "--cpus=0.5" # 0.5 CPU core max
        "--pids-limit=100" # Max 100 processes

        # Network: Isolated from other containers (uses default bridge)
        # If you want to proxy through Tailscale, add:
        # "--network=container:tailscaled"
      ];
    };
  };

  systemd.services.podman-noisy = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
