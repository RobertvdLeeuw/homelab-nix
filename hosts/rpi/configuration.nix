{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ../common-config.nix
  ]
  ++ (with inputs.nixos-raspberrypi.nixosModules; [
    raspberry-pi-4.base
    raspberry-pi-4.display-vc4
    raspberry-pi-4.bluetooth
  ]);

  networking.hostName = "nixos-rpi";

  # Use the new generational bootloader (recommended for new installs)
  boot.loader.raspberry-pi.bootloader = "kernel";

  # PWM Fan Control - Declarative equivalent to raspi-config fan setup
  # This configures the fan connected to GPIO 14 (TXD/physical pin 8)
  # Fan will turn on at the specified temp and off 10°C below that
  hardware.raspberry-pi.config = {
    all = {
      options = {
        # PWM fan: GPIO number (14 for TXD)
        dtoverlay = [
          {
            enable = true;
            params = {
              gpiopin = "14";
              temp = "60000"; # 10000 = 10C, 20000 = 20C, etc.
            };
            overlay = "gpio-fan";
          }
        ];
      };
    };
  };

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "prohibit-password";
  };

  # User configuration
  users.users.robert = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "gpio"
      "i2c"
    ];
  };

  # Install useful RPi tools
  environment.systemPackages = with pkgs; [
    libraspberrypi # Includes vcgencmd for temperature monitoring
    raspberrypi-eeprom
    git
  ];

  time.timeZone = "Europe/Amsterdam";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "24.11";
}
