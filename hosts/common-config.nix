{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  sops = {
    defaultSopsFile = ../secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";
    secrets."robert/password-hash".neededForUsers = true;
  };

  time.timeZone = "Europe/Amsterdam";

  services.openssh = {
    enable = true;
    ports = [
      # 22
      8022
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnsupportedSystem = true;
  };

  virtualisation.oci-containers.backend = "podman";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    substituters = [
      "https://cache.nixos.org/"
      "https://nixos-raspberrypi.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;

    users.robert = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMr5O7kjd7QpgiJxXq5TUCcabxDi5pjIz9R46RiMaxyo robert@desktop"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC18aM9hbDdpr/+Kg3RMoJ/Kpsi6AihcaA03tWELLsD8cGsy+cNSlRkbV8QCZS0cvtEbRasMq4CRKGOcTZVhXKqE4XC4wg4M7xR7a/Hj/enZHMQetxgcZhogpnSlTbvZfrvb27xfpv7g8Y1RmDdiv5IvkFU9HHNpocJp2VgHxK6pq83GeVbuxj+i4lVvB9+s+nnaJfGS8er1LSJe0+I8/9IwkPndpRF2+mMqnHpx9kQlzOFz2ccC+FOuXhINfBDqOHxkzn48yqhy2AwccIq9v/10eMKeskPdSWtNGaSlDnPt7tSpZxxPC+div9oF89I05hN97zAZnkWBav6azfOILK3brUb7KBqHV5YwFzVBr/OZsz6WYgg6oMmR6U0pWK3gZ+ubmLRGsJ8cTP42tj5XFM9VvyJwskox5i42Bz8JuRK7g8NZWIJFUKoF8rU6cYUY+Dze2KHGebS4+FmP+xgiutJxYu/79S3Y8qtJ9p04tz2bDPwG/mPj4oI96rv6C+PeCM= robert@desktop"

        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERovXoWJIAwmnXVX1XBSY1vNEdv+z/7Ud79kdZcKU3W robert@laptop"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCdY0rQ3u+NFyI9TYB4hyS2ONMyStW10q0K6FjHp4x/02NZYxwFFDX8I+prsZl4CO3JXFcFU5lOWqA67Z/ck/Hle5ut4RELksIvy+PTepL3d8AFtE7kHJSdchCf34Syj0wPtuNYjHWvwvsPOzTUgZjDsWcQgMUEqJmk/WaiHCYhygOPymdmqYoQ6RYj0AR3w2Crc4Y+1Wl1BNNpLCkqbTJl6mvhUFkqfnXOED2650kZHwehZcgzC+XEQr+7C6BqHx0hgzh6f4XueWTeXJVoUv6W3Dl5o7KVYrW4gBRyD5WUmrzibrz9ul+QWi0OIo2DInWFv0wXfCSvLkn2pF2NgsvwiYAEZv6k2aCILyRJJWu6qNsvxQVOPrZQkHq497edRRhsCT2Lqbh7smAA7Di+mJenL1QMn2WHMS8jJVhJ9jug++HcjRriC0lOB4moK5ZNFgtYjkwUh0ceVGdlL7s+pKxT2qYEJVT6sUwlTUREd6sTvU9XTbhveQikRN4dEjWcqIx7EfTkMdKBCaoT3s6IxxDzgPwnrksQ67vNaonbwN8uA8L4TAc6KLK0wE15IuhLOeJwkDqu6OHuZUsYknKfGo2Qtc/lUVWr74oh4SYYpM1h+64gZ0GtFuo3/ygwqJjsJk9Zr8aT2rtXMM6jMq5tWnz1TqNIkcIWin/9ku4ih9hQ0Q==  robert@laptop"
      ];
      hashedPasswordFile = config.sops.secrets."robert/password-hash".path;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "sudo"
      ];
    };
  };

  environment = {
    # systemPackages = with pkgs; [  ];
    variables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
      EDITOR = "nvim"; # For SOPS
    };
  };

  programs.zsh.enable = true;

  system.stateVersion = "24.11"; # DON'T TOUCH!
}
