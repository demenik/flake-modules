# Usage

A guide on how to use flake-modules for creating modular
dotfiles.

## File structure

It is recommended to split your dotfiles into hosts, users, and modules:

```
dotfiles/
├── flake.nix
├── hosts/
│   ├── host1/default.nix
│   └── host2/default.nix
├── users/
│   └── user1/default.nix
└── modules/
    ├── module1.nix
    ├── module2/default.nix
    └── module3
        ├── default.nix
        ├── submodule1/default.nix
        └── submodule2/default.nix
```

## Creating the `flake.nix`

You can use the built-in generators to automatically create
all configurations:

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

  outputs = { flake-modules, ... } @ inputs: {
    # mkNixosConfigurations and mkHomeConfigurations support the following arguments:
    # - hostsDir: Path to a directory containing host configurations (optional)
    # - hosts: Attribute set of hostName to hostPath mapping (optional)
    # - inputs: The flake inputs (required)
    # - extraSpecialArgs: Extra arguments passed to modules (optional)
    # - extraModules: Extra NixOS/Home Manager modules to include (optional)
    nixosConfigurations = flake-modules.lib.mkNixosConfigurations {
      hostsDir = ./hosts;
      inherit inputs;
      extraSpecialArgs = { inherit inputs; };
    };

    homeConfigurations = flake-modules.lib.mkHomeConfigurations {
      hostsDir = ./hosts;
      inherit inputs;
    };
  };
}
```

## Creating a module

Everything is optional unless staten otherwise.

`moduleConfig`, `nixos`, and `home` can optionally take arguments like
`pkgs`, `inputs`, `lib`, `config`, ...

```nix
{lib, inputs, ...}: {
  # Required, but not necessarily unique
  name = "my-module";

  # Shared module config
  moduleOptions = with lib; {
    my-module.my-option = mkOption {
      #...
    };
  };

  # Define secrets
  secrets = {
    "my-secret" = {
      # Optional description displayed when not configured by the user/host
      description = "My module secret";

      # Can be either "nixos", "hm", or "both".
      # - "nixos": Must be configured in ./hosts, only usable inside NixOS config,
      #            uses /etc/ssh/ssh_host_ed25519_key by default
      # - "hm":     Must be configured in ./users, only usable inside HM config,
      #            uses ~/.ssh/id_ed25519 by default
      # - "both":  Must be configured in ./hosts, usable by both NixOS and HM,
      #            uses both keys by default
      usedBy = "hm";

      # Optional. Whether to generate assertions to ensure this secret is configured.
      # Defaults to true. If set to false, build-time assertions are skipped.
      required = true;
    };
  };

  # Define overlays
  overlays = {
    nixos = [
      # Applied only to NixOS package set (e.g. system packages, custom kernel patches)
      (final: prev: { })
    ];
    home = [
      # Applied only to Home Manager package set (e.g. standalone user packages)
      (final: prev: { })
    ];
    both = [
      # Applied to both NixOS and Home Manager package sets
      (final: prev: { })
    ];
  };

  # Import other modules as dependencies
  modules = [./other-module.nix];

  # Configure modules
  moduleConfig = {
    other-modules.foo = "bar";
  };

  # Configure NixOS
  nixos = {pkgs, config, ...}: {
    # You can use config.my-module.my-option here
  };
  # Create host instructions that are displayed
  # if a standalone HM configuration is built
  hostInstructions = ''
    Install foo and configure bar
  '';

  home = {pkgs, config, ...}: {
    # You can use config.my-module.my-option here aswell
  };
}
```

## Configuring a host

A host configuration represents a physical or virtual machine. It defines
system-level settings, hardware configurations, and provides host-level secrets
(required by modules with `usedBy = "nixos"` or `"both"`).

`nixosConfig` can optionally take arguments like `pkgs`, `inputs`, `lib`, `config`, ...

```nix
{lib, ...}: {
  # Optional. The hostname of the machine. Automatically configures networking.hostName.
  hostname = "host1";

  # Required. The architecture of the system.
  system = "x86_64-linux";

  # Both required
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  # Optional. Whether Home Manager should use the global NixOS package set.
  # Defaults to true. Set to false to isolate user package sets and overlays.
  useGlobalPkgs = true;

  # Define the users on this host.
  # User configs can be used on multiple hosts.
  users = [
    ../../users/user1
  ];

  # Import your modules here
  modules = [
    ../../modules/my-module.nix
  ];

  # Define host-level overlays
  overlays = {
    nixos = [ (final: prev: { }) ];
    home = [ (final: prev: { }) ];
    both = [ (final: prev: { }) ];
  };

  # Configure the imported modules for this specific host
  moduleConfig = {
    my-module.my-option = true;
  };

  # Provide actual files for the secrets declared by the modules.
  # Note: NixOS will only evaluate secrets declared with
  # usedBy = "nixos" or "both".
  secrets = {
    "my-secret" = {
      # Required. Path to the encrypted sops file.
      path = ../../secrets/secrets.sops.yaml;

      # Optional. The key inside the sops file to extract.
      # Defaults to the name of the secret ("my-secret").
      key = "other-secret";
    };
  };

  nixosConfig = {pkgs, config, ...}: {
    imports = [ ./hardware-configuration.nix ];

    networking.hostName = "host1";
    boot.loader.systemd-boot.enable = true;
  };

  homeConfig = {
    # You can also configure Home Manager here.
    # This config will apply to all users.
  };
}
```

## Creating a user

A user configuration defines user-specific settings and provides
user-level secrets (required by modules with `usedBy = "home"`).

Everything is optional unless stated otherwise.

`homeConfig` can optionally take arguments like `pkgs`, `inputs`, `lib`, `config`, ...

```nix
{lib, inputs, ...}: {
  # Required. The library will automatically create the Home Manager user
  username = "user1";

  # Import your framework modules here.
  modules = [
    ../../modules/git.nix
    ../../modules/neovim
  ];

  # Define user-level overlays
  overlays = {
    nixos = [ (final: prev: { }) ];
    home = [ (final: prev: { }) ];
    both = [ (final: prev: { }) ];
  };

  # Configure the imported modules for this specific user
  moduleConfig = {
    git.email = "demenik@example.com";
  };

  # Provide actual files for the secrets declared by the modules.
  # Note: Home Manager will evaluate secrets declared with
  # usedBy = "home" or "both".
  secrets = {
    "user-secret" = {
      path = ./secrets/user-secret.sops.yaml;
      # Automatically uses "user-secret" as the sopsKey if omitted
    };
  };

  homeConfig = {pkgs, config, ...}: {
    # Configure Home Manager here...
  };

  nixosConfig = {pkgs, config, ...}: {
    # You can also configure NixOS on user level, however these will
    # apply to the entire system (and therefore all users)
  };
}
```

## Custom Metadata & Open Schemas

All host, user, and module schemas are open-ended (`freeformType` is enabled). This allows you to attach custom metadata or arbitrary helper values directly at the root of your configurations without raising schema evaluation errors:

```nix
{ lib, ... }: {
  system = "x86_64-linux";
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  # Custom metadata fields are fully permitted:
  machineRole = "server";
  location = "rack-2a";
}
```

These custom fields can be accessed dynamically inside builders or other evaluation pipelines (e.g. via `host.machineRole`).

## Validation & Error Handling

To make configuration debugging easier, the framework performs proactive checks at evaluation time:
- **Path Existence Verification**: Prior to schema evaluation, the loader checks that files exist on disk, raising a clear `"Configuration path '...' does not exist on disk"` error instead of cryptic Nix internal path lookup errors.
- **Duplicate Module Name Detection**: When importing modules, the loader verifies that module names are unique across the transitively resolved closure. If two modules are defined at different filesystem paths with the same name, an error lists the duplicate name and the source paths.
