{lib, ...}: {
  name = "test";
  moduleOptions = {
    demenix.test.message = lib.mkOption {
      type = lib.types.str;
      default = "Hello World";
      description = "A test message";
    };
  };

  secrets = {
    test-both = {
      usedBy = "both";
      description = "Test NixOS and HM Secret";
    };
    test-nixos = {
      usedBy = "nixos";
      description = "Test NixOS Secret";
    };
    test-hm = {
      usedBy = "hm";
      description = "Test HM Secret";
    };
  };

  nixos = {config, ...}: {
    environment.etc."nixos-test.txt".text = config.demenix.test.message;

    assertions = [
      {
        assertion = config.sops.secrets ? test-both;
        message = "Secret for NixOS and HM should be available";
      }
      {
        assertion = config.sops.secrets ? test-nixos;
        message = "Secret for NixOS should be available";
      }
      {
        assertion = !(config.sops.secrets ? test-hm);
        message = "Secret for HM should not be available";
      }
    ];
  };
  hostInstructions = ''
    Create a file at '/etc/nixos-test.txt' with the content of option 'demenix.test.message'.
  '';

  home = {config, ...}: {
    home.file.".hm-test.txt".text = config.demenix.test.message;

    assertions = [
      {
        assertion = config.sops.secrets ? test-both;
        message = "Secret for NixOS and HM should be available";
      }
      {
        assertion = config.sops.secrets ? test-hm;
        message = "Secret for HM should be available";
      }
      {
        assertion = !(config.sops.secrets ? test-nixos);
        message = "Secret for NixOS should not be available";
      }
    ];
  };
}
