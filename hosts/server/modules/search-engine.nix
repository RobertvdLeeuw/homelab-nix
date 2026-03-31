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
    volumes = [
      "/var/lib/degoog:/app/data:rw"
    ];
    environment = {
      DEGOOG_PORT = "4444";
    };
    extraOptions = [
      "--network=host" # Needed to connect to SearXNG.
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

  # SearXNG backend (used by Degoog)
  sops.templates."searxng-env" = {
    content = ''
      SEARXNG_SECRET=${config.sops.placeholder."searxng/secret"}
    '';
  };

  services.searx = {
    enable = true;
    redisCreateLocally = true;

    environmentFile = config.sops.templates."searxng-env".path;

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "@SEARXNG_SECRET@"; # Will use sops template
        limiter = false; # Internal use only
        public_instance = false; # Not a public instance
        image_proxy = true;
      };

      search = {
        formats = [
          "json"
        ]; # Essential for degoog plugin
        safe_search = 0;
      };

      engines = lib.mapAttrsToList (name: value: { inherit name; } // value) {
        # Disable engines degoog already covers
        "google".disabled = true;
        "bing".disabled = true;
        "duckduckgo".disabled = true;
        "brave".disabled = true;
        "qwant".disabled = true;
        "reddit".disabled = true;

        # Academic/Research
        "arxiv".disabled = false;
        "pubmed".disabled = false;
        "semantic scholar".disabled = false;

        # Developer tools
        "npm".disabled = false;
        "crates".disabled = false;
        "pypi".disabled = false;
        "github".disabled = false;
        "stackoverflow".disabled = false;

        # Specialized knowledge
        "ddg definitions".disabled = false;
        "ddg definitions".weight = 2.0;
        "crowdview".disabled = false;
        "crowdview".weight = 0.5;
        "wikidata".disabled = true; # Too slow, you go.
        "library of congress".disabled = false;

        # Independent indexes (low weight for noise reduction)
        "mojeek".disabled = false;
        "mojeek".weight = 0.4;
        "mwmbl".disabled = true; # Timeouts
        "mwmbl".weight = 0.4;

        # Access denied
        "karmasearch".disabled = true;
        "karmasearch videos".disabled = true;
      };
    };
  };

  systemd.services.searx = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = hardening.hardened.standard // {
      BindReadOnlyPaths = [
        config.sops.templates."searxng-env".path
      ];

      # Restrict address families to what's actually needed
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
  };
}
