{lib, ...}: let
  common = import ./common.nix {inherit lib;};
in
  with lib; {
    freeformType = types.attrsOf types.raw;
    options = {
      username = mkOption {
        type = types.str;
        description = "User's Unix system login name.";
      };

      modules = mkOption {
        type = common.modulesType;
        default = [];
        description = "List of user-specific modular configuration paths to load.";
      };

      overlays = mkOption {
        default = {};
        type = common.overlaySubmodule;
        description = "User-level overlays declarations.";
      };

      moduleConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "User-specific configuration overrides for imported modules.";
      };
      nixosConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "User-specific NixOS configuration block (e.g. groups, shell).";
      };
      homeConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Raw user-level Home Manager configuration block.";
      };

      sshKeyPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the user's SSH key for sops decryption. Defaults to ~/.ssh/id_ed25519.";
      };
      gnupgKeyPaths = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of GPG key paths to use for sops decryption.";
      };
      secrets = mkOption {
        default = {};
        type = types.attrsOf common.secretBindingSubmodule;
        description = "User-level sops secret file configuration mapping.";
      };
    };
  }
