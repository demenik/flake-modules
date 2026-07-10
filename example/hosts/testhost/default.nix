{
  hostname = "testhost";
  system = "x86_64-linux";
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  users = [
    ../../users/testuser
    ../../users/testuser2
  ];
  modules = [
    {
      name = "my-external-module";
      moduleConfig = {};
    }
  ];

  secrets = {
    test-nixos = {
      path = ./secrets/test-nixos.yaml;
      hm = {
        decryptedPath = "/home/user/.secrets/test-nixos";
      };
    };
    test-both.path = ../../users/testuser/secrets/test-both.yaml;
  };

  nixosConfig = {
    boot.loader.systemd-boot.enable = true;

    fileSystems."/" = {
      device = "/dev/nvme0n1p3";
      fsType = "ext4";
    };
  };
}
