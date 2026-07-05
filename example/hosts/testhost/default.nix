{
  hostname = "testhost";
  system = "x86_64-linux";
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  users = [../../users/testuser];
  modules = [
    {
      name = "my-external-module";
      moduleConfig = {};
    }
  ];

  secrets = {
    test-nixos.path = ./secrets/test-nixos.yaml;
  };

  nixosConfig = {
    boot.loader.systemd-boot.enable = true;

    fileSystems."/" = {
      device = "/dev/nvme0n1p3";
      fsType = "ext4";
    };
  };
}
