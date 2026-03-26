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
    containers.degoog = {
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
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/degoog 0755 1000 1000 -"
  ];

  systemd.services.podman-degoog = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Hardening done in container options.
  };

  services.nginx.virtualHosts."${config.networking.hostName}".locations = {
    "/search" = {
      return = "301 /search/";
    };
    "/search/" = {
      proxyPass = "http://127.0.0.1:4444/";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;

        # Rewrite HTML content
        sub_filter 'href="/' 'href="/search/';
        sub_filter 'src="/' 'src="/search/';
        sub_filter 'action="/' 'action="/search/';
        sub_filter_once off;
        sub_filter_types text/html text/css application/javascript;
      '';
    };
  };
}
