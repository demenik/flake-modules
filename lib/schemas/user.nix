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
  };
}
