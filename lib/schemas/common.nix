{lib}:
with lib; {
  overlaySubmodule = types.submodule {
    options = {
      nixos = mkOption {
        type = types.listOf types.raw;
        default = [];
      };
      home = mkOption {
        type = types.listOf types.raw;
        default = [];
      };
      both = mkOption {
        type = types.listOf types.raw;
        default = [];
      };
    };
  };

  secretBindingSubmodule = types.submodule {
    options = {
      path = mkOption {type = types.path;};
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
}
