{lib, ...}:
with lib; {
  options = {
    system = mkOption {type = types.str;};
    stateVersion = mkOption {type = types.str;};
    hmStateVersion = mkOption {type = types.str;};

    users = mkOption {
      type = types.listOf types.path;
      default = [];
    };
    modules = mkOption {
      type = types.listOf types.path;
      default = [];
    };

    overlays = mkOption {
      default = {};
      type = types.submodule {
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
      type = types.str;
      default = "/etc/ssh/ssh_host_ed25519_key";
      description = "Path to the host's SSH key for sops decryption.";
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
