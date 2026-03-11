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
  };
}
