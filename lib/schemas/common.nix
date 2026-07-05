{lib}:
with lib; {
  overlaySubmodule = types.submodule {
    options = {
      nixos = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to the NixOS packages set.";
      };
      home = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to the Home Manager packages set.";
      };
      both = mkOption {
        type = types.listOf types.raw;
        default = [];
        description = "List of overlays applied to both NixOS and Home Manager packages sets.";
      };
    };
  };

  secretBindingSubmodule = types.submodule {
    options = {
      path = mkOption {
        type = types.path;
        description = "Path to the sops-encrypted file containing this secret.";
      };
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Key name inside the sops file to extract. Defaults to the secret name.";
      };
    };
  };

  modulesType = types.listOf (types.either types.path (types.submodule {
    options = {
      path = mkOption {
        type = types.path;
        description = "Path to the imported module.";
      };
      cond = mkOption {
        type = types.raw;
        description = "Condition predicate function taking system string.";
      };
    };
  }));
}
