{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common-config.nix
    ./hardware-configuration.nix
  ];

  networking = {
    hostName = "nixos-homelab";
    interfaces.enp4s0.wakeOnLan.enable = true;

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };
}
