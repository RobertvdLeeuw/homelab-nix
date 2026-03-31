{
  config,
  lib,
  pkgs,
  ...
}:

let
  common-tools = import ../../common-tools.nix { inherit lib; };
in
{
  sops = {
    secrets = {
      "cloudflare/api-token" = { };
      "cloudflare/tunnel-token" = { };
    };

    templates."cloudflared-token" = {
      content = ''
        ${config.sops.placeholder."cloudflare/tunnel-token"}
      '';
      owner = "cloudflared";
      mode = "0400";
    };
  };

  # Create cloudflared user
  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = { };

  # Manual systemd service using tunnel token
  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    script = ''
      exec ${pkgs.cloudflared}/bin/cloudflared tunnel run \
        --token $(cat ${config.sops.templates."cloudflared-token".path})
    '';

    serviceConfig = common-tools.hardening.standard // {
      User = "cloudflared";
      Group = "cloudflared";
      Restart = "on-failure";
      RestartSec = "5s";

      BindReadOnlyPaths = [
        config.sops.templates."cloudflared-token".path
      ];
    };
  };
}
