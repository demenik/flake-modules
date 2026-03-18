{lib, ...}:
with lib; {
  options = {
    # === Module ===
    name = mkOption {
      type = types.str;
      default = "unknown-module";
    };
    moduleOptions = mkOption {default = {};};

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
          required = mkOption {
            type = types.bool;
            default = true;
          };
        };
      });
    };
  };
}
