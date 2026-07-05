{lib, ...}: let
  common = import ./common.nix {inherit lib;};
in
  with lib; {
    options = {
      # === Module ===
      name = mkOption {
        type = types.str;
        default = "unknown-module";
        description = "Human-readable name of this module.";
      };
      moduleOptions = mkOption {
        type = types.attrs;
        default = {};
        description = "Custom options declarations introduced by this module.";
      };

      # === Modules ===
      modules = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "List of dependency module file/folder paths imported by this module.";
      };
      moduleConfig = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Default configuration settings applied to custom options declared in this or other modules.";
      };

      # === Overlays ===
      overlays = mkOption {
        default = {};
        type = common.overlaySubmodule;
        description = "Overlays exposed by this module.";
      };

      # === NixOS ===
      nixos = mkOption {
        type = types.deferredModule;
        default = {};
        description = "NixOS-specific configuration block contributed by this module.";
      };
      hostInstructions = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Instructions shown to users when this module contains NixOS settings but is built on a standalone Home Manager target.";
      };

      # === Home-Manager ===
      home = mkOption {
        type = types.deferredModule;
        default = {};
        description = "Home Manager-specific configuration block contributed by this module.";
      };

      # === Secrets ===
      secrets = mkOption {
        default = {};
        type = types.attrsOf (types.submodule {
          options = {
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Human-readable explanation of this secret (displayed during validation failures).";
            };
            usedBy = mkOption {
              type = types.enum ["nixos" "hm" "both"];
              description = "Where the secret is decrypted and used. 'nixos' and 'both' imply host-level decryption, 'hm' implies user-level decryption.";
            };
            required = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to assert at build time that this secret is configured.";
            };
          };
        });
        description = "Secrets declared as required or optional dependencies by this module.";
      };
    };
  }
