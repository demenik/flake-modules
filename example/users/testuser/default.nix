{
  username = "testuser";

  modules = [../../modules/test];
  moduleConfig = {
    demenix.test.message = "Test";
  };

  secrets = {
    test-hm.path = ./secrets/test-hm.yaml;
    test-both.path = ./secrets/test-both.yaml;
  };

  nixosConfig = {
    users.users.testuser = {
      isNormalUser = true;
    };
  };
}
