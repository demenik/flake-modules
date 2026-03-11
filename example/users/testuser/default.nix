{
  username = "testuser";

  modules = [../../modules/test];
  moduleConfig = {
    demenix.test.message = "Test";
  };

  nixosConfig = {
    users.users.testuser = {
      isNormalUser = true;
    };
  };
}
