{lib, ...}:
with lib; {
  options = {
    # === Module ===
    name = mkOption {
      type = types.str;
      default = "unknown-module";
    };
    moduleOptions = mkOption {default = {};};

    # === Modules ===
    modules = mkOption {
      type = types.listOf types.path;
      default = [];
    };
    moduleConfig = mkOption {
      type = types.deferredModule;
      default = {};
    };

    # === Overlays ===
    overlays = mkOption {
      default = {};
      type = types.submodule {
        options = {
          nixos = mkOption {
            type = types.listOf types.unspecified;
            default = [];
          };
          home = mkOption {
            type = types.listOf types.unspecified;
            default = [];
          };
          both = mkOption {
            type = types.listOf types.unspecified;
            default = [];
          };
        };
      };
    };

    # === NixOS ===
    nixos = mkOption {
      type = types.deferredModule;
      default = {};
    };
    hostInstructions = mkOption {
      type = types.nullOr types.lines;
      default = null;
    };

    # === Home-Manager ===
    home = mkOption {
      type = types.deferredModule;
      default = {};
    };

    # === Secrets ===
    secrets = mkOption {
      default = {};
      type = types.attrsOf (types.submodule {
        options = {
          description = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
          usedBy = mkOption {
            type = types.enum ["nixos" "hm" "both"];
            description = "Where the secret is decrypted and used. 'nixos' and 'both' imply decryption on the host, 'hm' implies decryption for the user.";
          };
          required = mkOption {
            type = types.bool;
            default = true;
            description = "Whether an assertion should be generated to ensure the secret is configured.";
          };
        };
      });
    };
  };
}
