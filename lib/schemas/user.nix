{lib, ...}: let
  common = import ./common.nix {inherit lib;};
in
  with lib; {
    options = {
      username = mkOption {type = types.str;};

      modules = mkOption {
        type = types.listOf types.path;
        default = [];
      };

      overlays = mkOption {
        default = {};
        type = common.overlaySubmodule;
      };

      moduleConfig = mkOption {
        type = types.deferredModule;
        default = {};
      };
      nixosConfig = mkOption {
        type = types.deferredModule;
        default = {};
      };
      homeConfig = mkOption {
        type = types.deferredModule;
        default = {};
      };

      sshKeyPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the user's SSH key for sops decryption. Defaults to ~/.ssh/id_ed25519.";
      };
      secrets = mkOption {
        default = {};
        type = types.attrsOf common.secretBindingSubmodule;
      };
    };
  }
