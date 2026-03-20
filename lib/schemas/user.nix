{lib, ...}:
with lib; {
  options = {
    username = mkOption {type = types.str;};

    users = mkOption {
      type = types.listOf types.path;
      default = [];
    };
    modules = mkOption {
      type = types.listOf types.path;
      default = [];
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

    secrets = mkOption {
      default = {};
      type = types.attrsOf (lib.types.submodule {
        options = {
          path = mkOption {type = types.path;};
          key = mkOption {
            type = types.nullOr types.str;
            default = null;
          };
        };
      });
    };
  };
}
