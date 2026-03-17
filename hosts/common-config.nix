{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # TODO: Make func or smth so I can overlay these (don't want unneeded secrets exposed on rPi)
  sops =
    let
      secretPaths = [
        "syncthing/password"
        "vaultwarden/admin-token"
        "tailscale/auth-key"
      ];
    in
    {
      defaultSopsFile = ../secrets.yaml;
      age.keyFile = "/var/lib/sops-nix/key.txt";
      secrets = lib.genAttrs secretPaths (_: { });
    };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  time.timeZone = "Europe/Amsterdam";

  services.openssh = {
    enable = true;
    ports = [ 8022 ];
  };

  nixpkgs.config.allowUnfree = true;

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

    users.robert = {
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
