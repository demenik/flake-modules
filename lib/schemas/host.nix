{lib, ...}: let
  common = import ./common.nix {inherit lib;};
in
  with lib; {
    options = {
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Explicit hostname for the host system.";
      };
      system = mkOption {
        type = types.str;
        description = "Target architecture/system identifier (e.g. x86_64-linux).";
      };
      stateVersion = mkOption {
        type = types.str;
        description = "NixOS system stateVersion for config compatibility.";
      };
      hmStateVersion = mkOption {
        type = types.str;
        description = "Home Manager stateVersion applied by default to all HM users.";
      };

      users = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of user configuration file paths to deploy on this host.";
      };
      modules = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of modular configuration folder/file paths to import on this host.";
      };

      overlays = mkOption {
        default = {};
        type = common.overlaySubmodule;
        description = "Host-level overlays declarations.";
      };

      moduleConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Host-wide settings configuration overrides for imported modules.";
      };
      nixosConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Raw NixOS system configuration block.";
      };
      homeConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Raw Home Manager configuration block applied globally to all users on this host.";
      };

      useGlobalPkgs = mkOption {
        type = types.bool;
        default = true;
        description = "Whether Home Manager should use the global NixOS package set (inheriting all overlays).";
      };

      sshKeyPath = mkOption {
        type = types.str;
        default = "/etc/ssh/ssh_host_ed25519_key";
        description = "Path to the host's SSH key for sops decryption.";
      };
      secrets = mkOption {
        default = {};
        type = types.attrsOf common.secretBindingSubmodule;
        description = "Host-level sops secret file configuration mapping.";
      };
    };
  }
