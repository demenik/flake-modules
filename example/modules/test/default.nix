{lib, ...}: {
  name = "test";
  moduleOptions = {
    demenix.test.message = lib.mkOption {
      type = lib.types.str;
      default = "Hello World";
      description = "A test message";
    };
  };

  secrets.test = {
    required = false;
    description = "Test Secret";
  };

  nixos = {config, ...}: {
    environment.etc."nixos-test.txt".text = config.demenix.test.message;
  };
  hostInstructions = ''
    Create a file at '/etc/nixos-test.txt' with the content of option 'demenix.test.message'.
  '';

  home = {config, ...}: {
    home.file.".hm-test.txt".text = config.demenix.test.message;
  };
}
