{
  # Raspberry Pi 4 — firmware (FAT) + ext4 root on MBR.
  # MBR on purpose: that is what the Pi firmware and the stock Pi images use.
  #
  # Do NOT put the backup/USB data disk in here: re-running disko
  # (nixos-anywhere, disko-install, disko --mode destroy) wipes every
  # disk declared in this file. Mount the data disk via fileSystems instead.
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/mmcblk0"; # SD card. Use /dev/sda if booting from a USB SSD.
    imageSize = "4G"; # Only used when building a disk image.
    content = {
      type = "table";
      format = "msdos";
      partitions = [
        {
          name = "firmware";
          start = "4MiB";
          end = "516MiB";
          fs-type = "fat32";
          bootable = true;
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot/firmware";
            mountOptions = [
              "fmask=0022"
              "dmask=0022"
            ];
            extraArgs = [
              "-n"
              "FIRMWARE"
            ];
          };
        }
        {
          name = "root";
          start = "516MiB";
          end = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            mountOptions = [ "noatime" ];
            extraArgs = [
              "-L"
              "NIXOS_SD"
            ];
          };
        }
      ];
    };
  };
}
