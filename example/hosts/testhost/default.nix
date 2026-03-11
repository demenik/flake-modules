{
  system = "x86_64-linux";
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  users = [../../users/testuser];
  modules = [];

  nixosConfig = {
    networking.hostName = "testhost";

    boot.loader.systemd-boot.enable = true;

    fileSystems."/" = {
      device = "/dev/nvme0n1p3";
      fsType = "ext4";
    };
  };
}
