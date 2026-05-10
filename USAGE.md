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

  outputs = { flake-modules, ... } @ inputs: let
    hostsDir = ./hosts;
  in {
    nixosConfigurations = flake-modules.lib.mkNixosConfigurations { inherit hostsDir inputs; };
    homeConfigurations  = flake-modules.lib.mkHomeConfigurations  { inherit hostsDir inputs; };
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

      # Can be either "nixos", "home", "both" or "none".
      # - "nixos": Must be configured in ./hosts, only usable inside NixOS config,
      #            uses /etc/ssh/ssh_host_ed25519_key by default
      # - "home":  Must be configured in ./users, only usable inside HM config,
      #            uses ~/.ssh/id_ed25519 by default
      # - "both":  Must be configured in ./hosts, usable by both NixOS and HM,
      #            uses both keys by default
      # - "none":  The secret is optional and is not checked at build time
      usedBy = "home";
    };
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
{lib, inputs, ...}: {
  # Required. The hostname of the machine.
  hostname = "host1";

  # Required. The architecture of the system.
  system = "x86_64-linux";

  # Both required
  stateVersion = "25.11";
  hmStateVersion = "25.11";

  # Define the users on this host.
  # User configs can be used on multiple hosts.
  users = [
    ../../users/user1
  ];

  # Import your modules here
  modules = [
    ../../modules/my-module.nix
  ];

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
