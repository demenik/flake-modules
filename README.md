# flake-modules

A highly modular and scalable framework for managing NixOS and Home Manager
configurations with Nix Flakes ❄️

## Important Notice!

This framework is still in early development. Breaking changes will happen
as this project ages. Make sure to test your config after updating flake-modules.

## Key Features

- **Unified Modules**: Write a single module that contains both NixOS (system)
  and Home Manager (user) configurations, keeping related code in one place.
- **Module Dependencies**: The module loader automatically resolves module
  dependencies, allowing modules to require each other.
- **Shared options**: Create `moduleOptions` which are injected into both NixOS
  and Home Manager to configure modules.
- **Configuration Generation**: The library automatically generates NixOS configurations
  for all hosts and Home Manager configurations for each user on each system.
  - By default this framework bundles the Home Manager config inside
    the NixOS configurations.
- **Secrets Managment**: Define secret requirements using `sops-nix` inside modules, which prompt
  users to configure them on rebuild.
- **Auto-Update Overlays**: The framework provides a builder for a CLI tool (`nix run .#overlay-update`) that you can
  use inside your configuration that allows you to easily update `rev` and `hash` fields of fetcher-based overlay packages.

## Quick Start

To use this framework in your own configurations, add
it as an input to your `flake.nix`:

```nix
{
  description = "My modular Nix configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-modules = {
      url = "github:demenik/flake-modules";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { flake-modules, nixpkgs, ... } @ inputs: let
    hostsDir = ./hosts;
  in {
    nixosConfigurations = flake-modules.lib.mkNixosConfigurations { inherit hostsDir inputs; };
    homeConfigurations  = flake-modules.lib.mkHomeConfigurations  { inherit hostsDir inputs; };

    apps."x86_64-linux".overlay-update = flake-modules.lib.mkUpdaterApp {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      inherit hostsDir inputs;
    };
  };
}
```

See [USAGE.md](/USAGE.md) for guides on creating modules, hosts and users.

## Examples

You can find an example configuration [here](/example) or
see [my dotfiles](https://github.com/demenik/dots) using flake-modules.

## License

This project falls under the [MIT License](/LICENSE).
