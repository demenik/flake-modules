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
          requiredBy = mkOption {
            type = types.enum ["nixos" "home" "both" "none"];
            default = "home";
            description = "Scope of the secret. 'nixos' and 'both' must be configured in the host config, while 'home' is configured in the user config";
          };
        };
      });
    };
  };
}
