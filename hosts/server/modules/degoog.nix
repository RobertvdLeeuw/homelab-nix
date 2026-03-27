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
  virtualisation.oci-containers.containers.degoog = {
    image = "ghcr.io/fccview/degoog:latest";
    ports = [ "127.0.0.1:4444:4444" ];
    volumes = [
      "/var/lib/degoog:/app/data:rw"
    ];
    environment = {
      DEGOOG_PORT = "4444";
    };
    extraOptions = [
      "--user=1000:1000"
      "--security-opt=label=disable"
      "--cap-drop=ALL"
      "--cap-add=CHOWN"
      "--cap-add=SETGID"
      "--cap-add=SETUID"
      "--read-only"
      "--tmpfs=/tmp"
    ];
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/degoog 0755 1000 1000 -"
    ];

    services.podman-degoog = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Hardening done in container options.
    };
  };

  services.nginx.virtualHosts."search.rvdlserver.nl" = {
    forceSSL = true;
    useACMEHost = "rvdlserver.nl";

    locations."/" = {
      proxyPass = "http://127.0.0.1:4444";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
      '';
    };
  };
}
