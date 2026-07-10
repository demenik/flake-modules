{
  description = "Module framework for dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    lib = import ./lib {
      inherit nixpkgs home-manager;
      inherit (nixpkgs) lib;
      lib-inputs = inputs;
    };

    hostsDir = ./example/hosts;
    nixosConfigurations = lib.mkNixosConfigurations {inherit hostsDir inputs;};
    homeConfigurations = lib.mkHomeConfigurations {inherit hostsDir inputs;};
  in {
    inherit lib;

    checks."x86_64-linux" = let
      nixosChecks =
        nixpkgs.lib.mapAttrs' (
          name: config:
            nixpkgs.lib.nameValuePair "nixos-${name}" config.config.system.build.toplevel
        )
        nixosConfigurations;

      homeChecks =
        nixpkgs.lib.mapAttrs' (
          name: config:
            nixpkgs.lib.nameValuePair "home-${name}" config.activationPackage
        )
        homeConfigurations;
    in
      nixosChecks // homeChecks;

    apps."x86_64-linux".overlay-update = lib.mkUpdaterApp {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit hostsDir inputs;
    };

    inherit nixosConfigurations homeConfigurations;
  };
}
