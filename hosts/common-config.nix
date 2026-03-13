{
  config,
  lib,
  pkgs,
  ...
}:

{
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
    ];
  };

  environment.variables = {
	EDITOR = "nvim";  # For SOPS
  };

  system.stateVersion = "24.11"; # DON'T TOUCH!
}
