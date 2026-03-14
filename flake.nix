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
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
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
                users = {
                  robert.imports = [ dotfiles.shellEnv ];
                  root.imports = [ dotfiles.shellEnv ];
                };
              };
            }
          ];
          specialArgs = {
            inherit inputs;
          };
        };

        rpi = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/rpi/configuration.nix

            sops-nix.nixosModules.sops
            # home-manager.nixosModules.home-manager
            # {
            #   home-manager = {
            #     useGlobalPkgs = true;
            #     useUserPackages = true;
            #     extraSpecialArgs = {
            #       inherit inputs;
            #       hostType = "rpi";
            #     };
            #     users = {
            #       robert = import ./hosts/laptop/home.nix;
            #       root = import ./hosts/laptop/home-root.nix;
            #     };
            #   };
            # }
          ];
          specialArgs = {
            inherit inputs;
          };
        };
      };

      checks.x86_64-linux = {
        server = self.nixosConfigurations.server.config.system.build.toplevel;
        rpi = self.nixosConfigurations.rpi.config.system.build.toplevel;
      };
    };
}
