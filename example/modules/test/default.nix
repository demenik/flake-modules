{lib, ...}: {
  name = "test";
  moduleOptions = {
    demenix.test.message = lib.mkOption {
      type = lib.types.str;
      default = "Hello World";
      description = "A test message";
    };
  };

  modules = [
    {
      path = ./linux-only.nix;
      cond = system: system == "x86_64-linux";
    }
  ];

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

  overlays = {
    nixos = [
      (final: prev: {
        nixosOnlyVal = "nixos-only";
      })
    ];
    home = [
      (final: prev: {
        homeOnlyVal = "home-only";
      })
    ];
    both = [
      (final: prev: {
        bothVal = "both-val";
      })
    ];
  };

  nixos = {
    pkgs,
    config,
    ...
  }: {
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
      {
        assertion = pkgs ? nixosOnlyVal && pkgs.nixosOnlyVal == "nixos-only";
        message = "NixOS-only overlay value should be available";
      }
      {
        assertion = pkgs ? bothVal && pkgs.bothVal == "both-val";
        message = "Both overlay value should be available in NixOS";
      }
      {
        assertion = pkgs ? homeOnlyVal && pkgs.homeOnlyVal == "home-only";
        message = "Home-only overlay value should be available in NixOS (since home-manager uses global pkgs)";
      }
    ];
  };
  hostInstructions = ''
    Create a file at '/etc/nixos-test.txt' with the content of option 'demenix.test.message'.
  '';

  home = {
    pkgs,
    config,
    isStandalone ? false,
    ...
  }: {
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
      {
        assertion = pkgs ? bothVal && pkgs.bothVal == "both-val";
        message = "Both overlay value should be available in Home Manager";
      }
      {
        assertion = pkgs ? homeOnlyVal && pkgs.homeOnlyVal == "home-only";
        message = "Home-only overlay value should be available in Home Manager";
      }
      {
        assertion =
          if isStandalone
          then !(pkgs ? nixosOnlyVal)
          else true;
        message = "NixOS-only overlay value should NOT be available in standalone Home Manager";
      }
    ];
  };
}
