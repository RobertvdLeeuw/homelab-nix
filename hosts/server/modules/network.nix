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
    tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets."tailscale/auth-key".path;
      useRoutingFeatures = "server";
      extraUpFlags = [ "--ssh" ];
    };

    nginx = {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      proxyTimeout = "3600s";
      commonHttpConfig = ''
        proxy_headers_hash_max_size 1024;
        proxy_headers_hash_bucket_size 128;
      '';

      # virtualHosts."rvdlserver.nl" = {
      #   forceSSL = true;
      #   useACMEHost = "rvdlserver.nl";
      #   locations = { };
      # };
    };
  };

  networking.firewall = {
    allowedUDPPorts = [ config.services.tailscale.port ];

    # Allow Tailscale traffic
    trustedInterfaces = [ "tailscale0" ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/tailscale 0711 root root - -" # For NGINX to read certificates
    ];

    services = {
      tailscaled = {
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        serviceConfig = hardening.hardened.base // {
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
          ReadWritePaths = [ "/var/lib/tailscale" ];
          SystemCallFilter = [
            "@system-service"
            "@network-io"
          ];
        };
      };

      nginx = {
        after = [ "tailscale.service" ];
        wants = [ "tailscale.service" ];

        serviceConfig = hardening.hardened.standard // {
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
    };
  };
}
