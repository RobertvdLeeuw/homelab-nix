{ config, lib, ... }:
{
  topology = {
    nodes = {
      internet = {
        deviceType = "internet";
        hardware.info = "Internet";
        interfaces.wan = { };
      };

      router = {
        deviceType = "router";
        hardware.info = "Home Router";

        interfaces.wan = {
          network = "internet";
          physicalConnections = [
            {
              node = "internet";
              interface = "wan";
              # type = "wired";
            }
          ];
        };

        interfaces.lan = {
          network = "lan";
        };
      };

      ${config.networking.hostName} = {
        deviceType = lib.mkForce "server";
        hardware.info = "Homelab Server";

        interfaces.enp4s0 = {
          addresses = [ "dhcp" ];
          network = "lan";
          physicalConnections = [
            {
              node = "router";
              interface = "lan";
              # type = "wired";
            }
          ];
        };

        interfaces.tailscale0 = {
          addresses = [ "100.79.157.102" ];
          network = "tailscale";
          virtual = true;
          type = "wireguard";
        };

        services = {
          nginx = {
            name = "NGINX";
            info = "Reverse proxy (443)";
          };

          vaultwarden = {
            name = "Vaultwarden";
            info = "Password manager (8222)";
          };

          syncthing = {
            name = "Syncthing";
            info = "File sync (8384)";
          };

          adguardhome = {
            name = "AdGuard Home";
            info = "DNS + ad blocking (3003, 53)";
          };

          homepage-dashboard = {
            name = "Homepage";
            info = "Dashboard (3001)";
          };

          degoog = {
            name = "Degoog";
            info = "Private search (4444)";
          };
        };
      };
    };

    networks = {
      internet = {
        name = "Internet";
        cidrv4 = "0.0.0.0/0";
      };

      lan = {
        name = "Home LAN";
        cidrv4 = "192.168.1.0/24";
      };

      tailscale = {
        name = "Tailscale Mesh";
        cidrv4 = "100.64.0.0/10";
      };
    };
  };
}
