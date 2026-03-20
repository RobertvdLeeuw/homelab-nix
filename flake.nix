{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    dotfiles.url = "github:RobertvdLeeuw/dotfiles_nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      nixos-raspberrypi,
      dotfiles,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        server = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/server/configuration.nix

            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules = [ (dotfiles.shellEnv { hostType = "server"; }) ];
                extraSpecialArgs.hostType = "server";

                users = {
                  robert.home = {
                    username = "robert";
                    homeDirectory = "/home/robert";
                    stateVersion = "24.11";
                  };
                  root.home = {
                    username = "root";
                    homeDirectory = "/root";
                    stateVersion = "24.11";
                  };
                };
              };
            }
          ];
          specialArgs = {
            inherit inputs;
          };
        };

        rpi = nixos-raspberrypi.lib.nixosSystem {
          specialArgs = { inherit inputs nixos-raspberrypi; };
          modules = [
            ./hosts/rpi/configuration.nix

            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                sharedModules = [ (dotfiles.shellEnv { hostType = "rpi"; }) ];
                extraSpecialArgs.hostType = "rpi";

                users = {
                  robert.home = {
                    username = "robert";
                    homeDirectory = "/home/robert";
                    stateVersion = "24.11";
                  };
                  root.home = {
                    username = "root";
                    homeDirectory = "/root";
                    stateVersion = "24.11";
                  };
                };
              };
            }
          ];
        };
      };

      checks.x86_64-linux = {
        x86_64-linux.server = self.nixosConfigurations.server.config.system.build.toplevel;
        aarch64-linux.rpi = self.nixosConfigurations.rpi.config.system.build.toplevel;
      };
    };
}
