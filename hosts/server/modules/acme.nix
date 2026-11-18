{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  facts = inputs.dotfiles.lib.facts;
in
{
  sops.templates."acme-cloudflare-env" = {
    content = ''
      CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/api-token"}
    '';
    owner = "acme";
    mode = "0400";
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "robert.van.der.leeuw@gmail.com";

    certs.${facts.domain} = {
      domain = "*.${facts.domain}";
      extraDomainNames = [ facts.domain ];

      dnsProvider = "cloudflare";
      environmentFile = config.sops.templates."acme-cloudflare-env".path;

      # Allow nginx to read the certificates
      group = "nginx";
    };
  };
}
