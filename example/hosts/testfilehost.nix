{
  hostname = "testfilehost";
  system = "x86_64-linux";
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  users = [../users/testuser];
  modules = [];

  secrets = {
    test-nixos.path = ./testhost/secrets/test-nixos.yaml;
    test-both.path = ../users/testuser/secrets/test-both.yaml;
  };

  nixosConfig = {
    boot.loader.systemd-boot.enable = true;

    fileSystems."/" = {
      device = "/dev/nvme0n1p3";
      fsType = "ext4";
    };
  };
}
