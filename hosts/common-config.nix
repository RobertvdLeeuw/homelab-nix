{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];
  sops =
    let
      secretPaths = [
        "syncthing/password"
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

  users.users.robert = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "sudo"
    ];
    packages = with pkgs; [
      git
      neovim
      sops
      tree
      dust
    ];
  };

  environment.variables = {
    EDITOR = "nvim"; # For SOPS
  };

  system.stateVersion = "24.11"; # DON'T TOUCH!
}
