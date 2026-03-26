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
  sops.templates."vaultwarden.env" = {
    content = ''
      ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}
    '';
    owner = "vaultwarden";
    mode = "0400";
  };

  services = {
    vaultwarden = {
      enable = true;
      backupDir = "/var/local/vaultwarden/backup";
      environmentFile = config.sops.templates."vaultwarden.env".path;
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        ROCKET_LOG = "critical";

        DOMAIN = "https://vault.${config.networking.hostName}";

        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = false;
      };
    };

    nginx.virtualHosts."vault.rvdlserver.nl" = {
      forceSSL = true;
      useACMEHost = "rvdlserver.nl";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header Host $host;

          proxy_read_timeout 3600;
          proxy_connect_timeout 3600;
          proxy_send_timeout 3600;
        '';
      };
    };
  };

  systemd.services.vaultwarden = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = hardening.hardened.standard // {
      # Vaultwarden needs to write to its data directory
      ReadWritePaths = [
        "/var/lib/vaultwarden"
        "/var/local/vaultwarden"
      ];
      BindReadOnlyPaths = [
        config.sops.templates."vaultwarden.env".path
      ];
    };
  };
}
