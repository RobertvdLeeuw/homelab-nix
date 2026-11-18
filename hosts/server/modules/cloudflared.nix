{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  common-tools = import ../../common-tools.nix { inherit lib; };
  tunnel-id = "fe346776-2b22-4144-8c5e-66e41107dfdc";
  facts = inputs.dotfiles.lib.facts;
in
{
  sops = {
    secrets = {
      "cloudflare/api-token" = { }; # Used by ACME (acme.nix).
      "cloudflare/tunnel-credentials" = { }; # Full credentials JSON, stored as a string.
    };
  };

  services.cloudflared = {
    enable = true;

    tunnels.${tunnel-id} = {
      credentialsFile = config.sops.secrets."cloudflare/tunnel-credentials".path;
      default = "http_status:404";

      ingress = {
        "cal.${facts.domain}" = "http://127.0.0.1:5232"; # Radicale
      };
    };
  };

  # Module creates a DynamicUser unit; keep the hardening tier on top.
  systemd.services."cloudflared-tunnel-${tunnel-id}".serviceConfig = common-tools.hardening.standard;
}
